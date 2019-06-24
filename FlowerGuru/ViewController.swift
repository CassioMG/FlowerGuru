//
//  ViewController.swift
//  FlowerGuru
//
//  Created by Cássio Marcos Goulart on 17/06/19.
//  Copyright © 2019 CMG Solutions. All rights reserved.
//

import UIKit
import CoreML
import Vision
import Alamofire
import SwiftyJSON
import SVProgressHUD

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    private let imagePicker = UIImagePickerController()
    
    @IBOutlet weak var searchButton: UIBarButtonItem!
    @IBOutlet weak var cameraButton: UIBarButtonItem!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var extractTextLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        imagePicker.delegate = self
        imagePicker.allowsEditing = true
        
        extractTextLabel.text = ""
    }
    
    @IBAction func searchTapped(_ sender: UIBarButtonItem) {
        present(imagePicker, withSourceType: .photoLibrary)
    }
    
    @IBAction func cameraTapped(_ sender: UIBarButtonItem) {
        present(imagePicker, withSourceType: .camera)
    }
    
    private func present(_ imagePicker: UIImagePickerController, withSourceType sourceType: UIImagePickerController.SourceType) {
        
        if UIImagePickerController.isSourceTypeAvailable(sourceType) {
            imagePicker.sourceType = sourceType
            present(imagePicker, animated: true, completion: nil)
            
        } else {
            var sourceTypeString = ""
            
            switch(sourceType) {
            case .camera: sourceTypeString = "Camera"
            case .photoLibrary: sourceTypeString = "Photo Library"
            case .savedPhotosAlbum: sourceTypeString = "Photos Album"
            default: sourceTypeString = "Unknown Source Type"
            }
            
            print("Sorry, \(sourceTypeString) source type is not available.")
        }
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        if let userPickedImage = info[UIImagePickerController.InfoKey.editedImage] as? UIImage,
            let cIImage = CIImage(image: userPickedImage) {
            
            imageView.image = userPickedImage
            extractTextLabel.text = ""
            
            detect(flowerImage: cIImage)
        }
        
        picker.dismiss(animated: true, completion: nil)
    }
    
    private func detect(flowerImage: CIImage) {
        
        DispatchQueue.main.async { SVProgressHUD.show() }
        
        guard let model = try? VNCoreMLModel(for: FlowerClassifier().model) else {
            fatalError("Couldn't load VNCoreMLModel using FlowerClassifier")
        }
        
        let request = VNCoreMLRequest(model: model) { (vnRequest, error) in
            
            guard let results = vnRequest.results as? [VNClassificationObservation] else {
                fatalError("Failed to get results from VNCoreMLRequest as [VNClassificationObservation]")
            }
            
            print("\nAll Identifiers: \(results.map{ $0.identifier })\n")

            if let identifier = results.first?.identifier {
                
                self.navigationItem.title = "This is a \(identifier.capitalized) flower!"
                
                self.requestWikiData(forFlower: identifier)
                
            } else {
                DispatchQueue.main.async { SVProgressHUD.dismiss() }
            }
        }
        
        let handler = VNImageRequestHandler(ciImage: flowerImage)
        
        do{
            try handler.perform([request])
        } catch {
            print("Error trying to perform VNCoreMLRequest: \(error)")
            DispatchQueue.main.async { SVProgressHUD.dismiss() }
        }
    }
    
    private func requestWikiData(forFlower flower: String) {
        
        let wikipediaURl = "https://en.wikipedia.org/w/api.php"
        
        let parameters : [String:String] = [
            "format" : "json",
            "action" : "query",
            "prop" : "extracts",
            "exintro" : "",
            "explaintext" : "",
            "titles" : flower,
            "indexpageids" : "",
            "redirects" : "1",
        ]
        
        request(wikipediaURl, method: .get, parameters: parameters).responseJSON { (response) in
            
            // print("RESPONSE: ", response)
            
            if response.result.isSuccess {
             
                if let responseValue = response.result.value {
                    
                    let json = JSON(responseValue)
                    
                    if let pageId = json["query"]["pageids"][0].string {
                        
                        let extractText = json["query"]["pages"][pageId]["extract"]
                        
                        self.extractTextLabel.text = extractText.string
                        
                        print("THIS IS THE EXTRACT: ", extractText)
                    }
                }
                
            } else {
                print("ERROR GETTING FLOWER DATA FROM WIKIPEDIA: ", response)
                self.extractTextLabel.text = "Couldn't get flower info from Wikipedia."
            }
            
            self.extractTextLabel.sizeToFit()
            
            DispatchQueue.main.async { SVProgressHUD.dismiss() }
        }
    }
    
    
}


