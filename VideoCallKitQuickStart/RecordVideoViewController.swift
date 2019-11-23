import UIKit
import AWSS3
import AWSCore
import MobileCoreServices

class RecordVideoViewController: UIViewController {
    

  
  @IBAction func record(_ sender: AnyObject) {
    VideoHelper.startMediaBrowser(delegate: self, sourceType: .camera)
  }
  
  @objc func video(_ videoPath: String, didFinishSavingWithError error: Error?, contextInfo info: AnyObject) {
    let title = (error == nil) ? "Success" : "Error"
    let message = (error == nil) ? "Video was saved" : "Video failed to save"
    
    let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.cancel, handler: nil))
    present(alert, animated: true, completion: nil)
  }
  
}


// MARK: - UIImagePickerControllerDelegate

extension RecordVideoViewController: UIImagePickerControllerDelegate {
  func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
    dismiss(animated: true, completion: nil)
    
    guard let mediaType = info[UIImagePickerController.InfoKey.mediaType] as? String,
      mediaType == (kUTTypeMovie as String),
      let url = info[UIImagePickerController.InfoKey.mediaURL] as? URL,
      UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(url.path)
      else { return }
    
    
    // Initialize the Amazon Cognito credentials provider
    let IDENTITY_POOL_ID = "us-west-2:95c1f9b0-ffc0-4ecd-9083-82783ea4e65d"
    let S3_BUCKET_NAME = "bridge-media"
    
    let S3BucketName = S3_BUCKET_NAME
    let credentialsProvider = AWSCognitoCredentialsProvider(regionType:.USWest2,
       identityPoolId:IDENTITY_POOL_ID)
    let configuration = AWSServiceConfiguration(region:.USWest2, credentialsProvider:credentialsProvider)
    AWSServiceManager.default().defaultServiceConfiguration = configuration
    
    // prepare the actual uploader
    if let uploadRequest = AWSS3TransferManagerUploadRequest() {
        uploadRequest.body = url
        uploadRequest.key = ProcessInfo.processInfo.globallyUniqueString + ".mp4"
        uploadRequest.bucket = S3BucketName
        uploadRequest.contentType = "movie/mp4"
        uploadRequest.acl = .publicRead
        
        let transferManager = AWSS3TransferManager.default()
        transferManager.upload(uploadRequest).continueWith(executor: AWSExecutor.mainThread()) { (task) -> Any? in
            if let error = task.error {
                print(error)
            }
            if task.result != nil {
                print("Uploaded \(uploadRequest.key)")
            }
            
            return nil
        }
        
        
        let BUCKET_ROOT = "https://bridge-media.s3-us-west-2.amazonaws.com"
        let API_ROOT = "https://rp2k1rvvn3.execute-api.us-west-2.amazonaws.com/dev"
        let url = URL(string: API_ROOT + "/messages")!
        var request = URLRequest(url: url)
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")
        request.httpMethod = "POST"

        let body = ["source": "grandson",
                    "type": "video",
                    "video_url": BUCKET_ROOT + "/" + uploadRequest.key!,
                    "thumbnail_url": "filler",
                    "file_name": uploadRequest.key!]
        request.httpBody = try! JSONEncoder().encode(body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print(error?.localizedDescription ?? "No data")
                return
            }
            let responseJSON = try? JSONSerialization.jsonObject(with: data, options: [])
            if let responseJSON = responseJSON as? [String: Any] {
                print(responseJSON)
            }
        }.resume()
    }
    
  }
  
}


// MARK: - UINavigationControllerDelegate

extension RecordVideoViewController: UINavigationControllerDelegate {
}
