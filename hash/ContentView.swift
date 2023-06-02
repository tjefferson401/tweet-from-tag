//
//  ContentView.swift
//  hash
//
//  Created by TJ Jefferson on 6/1/23.
//
import SwiftUI
import UIKit
import Foundation


func callOpenAI(prompt: String, completion: @escaping (String) -> ()) {
    // Prepare URL and request
    let url = URL(string: "https://api.openai.com/v1/completions")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    var key = ""
    if let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
        let dict = NSDictionary(contentsOfFile: path) as? [String: AnyObject] {
            let apiKey = dict["OPENAI_API"] as? String
            // Now you can use this apiKey where you need it
        key = apiKey ?? "";
    }
    if(key == "") {
        return;
    }
    request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json", forHTTPHeaderField: "Accept")

    // Set the input text and other parameters
    let parameters: [String: Any] = [
        "model": "text-davinci-003",
        "prompt": "Generate a tweet based on the following hashtag(s): '\(prompt)'. Make sure to include the hashtags in the tweet.",
        "max_tokens": 100
    ]
    
    print(parameters)

    // Convert parameters to JSON data
    let jsonData = try! JSONSerialization.data(withJSONObject: parameters, options: [])
    
    // Attach JSON data to the request
    request.httpBody = jsonData
    
    // Send the request
    URLSession.shared.dataTask(with: request) { (data, response, error) in
        // Check if there was an error
        if let error = error {
            print("Error: \(error)")
            return
        }

        // Check if data was received
        guard let data = data else {
            print("No data received.")
            return
        }
        
        // Attempt to decode the data as JSON
        do {
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let text = firstChoice["text"] as? String {
                print("json")
                print(json)
                DispatchQueue.main.async {
                    print("IN CALL Completion")
                    print(text)
                    completion(text)
                }

            } else {
                print("Couldn't parse the AI's response from JSON")
            }
        } catch {
            print("Failed to decode JSON: \(error)")
        }
    }.resume()
}


struct TextViewDisplay: View {
    var text: String
    let placeholder = "What's happening?"

    var body: some View {
        ScrollView {
            VStack {
                Text(text.isEmpty ? placeholder : text)
                    .foregroundColor(.gray)
                    .font(.system(size: 14))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        }
        .background(Color.white)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray, lineWidth: 1)
        )
        .frame(height: 150)
    }
}



struct TextView: UIViewRepresentable {
    
    @Binding var text: String
    let maxCharacterLimit = 280
    let placeholder: String
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.text = placeholder
        textView.textColor = .lightGray
        textView.font = UIFont.systemFont(ofSize: 14)
        // Add border
         textView.layer.borderWidth = 1.0
         textView.layer.borderColor = UIColor.gray.cgColor
         textView.layer.cornerRadius = 8.0
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if text == "" {
            uiView.text = placeholder
            uiView.textColor = .lightGray
        } else {
            uiView.text = text
            uiView.textColor = .white
        }
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: TextView

        init(_ parent: TextView) {
            self.parent = parent
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            if textView.textColor == UIColor.lightGray {
                textView.text = "#"
                textView.textColor = UIColor.black
            }
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            if textView.text.isEmpty {
                textView.text = parent.placeholder
                textView.textColor = UIColor.lightGray
            }
            parent.text = textView.text
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            // If a space is inserted, automatically insert a # as well
            if text == " " {
                textView.text.append(" #")
                return false
            }
            // If the delete key is detected
            else if text.isEmpty {
                // If the first character is being deleted, prevent it
                if range.location == 0 && range.length == 1 {
                    return false
                }
                // If the last character is a #, remove it and the preceding space
                if textView.text.hasSuffix("#") {
                    textView.text.removeLast(2) // Remove last two characters (space and #)
                    return false
                }
            }
            return true
        }
    }

}



struct ContentView: View {
    @State private var text = "#"
    @State private var responseText = ""
    @State private var isLoading = false
    @State private var spinAnimation = false


    var body: some View {
        VStack {
            
            if(responseText != "") {
                Button(action: {
                    UIPasteboard.general.string = responseText
                }) {
                    HStack {
                        Image(systemName: "doc.on.doc") // Use a built-in symbol
                            .foregroundColor(.white)
                        Text("Copy to Clipboard")
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.gray)
                    .cornerRadius(8)
                }
                .padding()
            }
            
            if isLoading {
                Image(systemName: "flame.circle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 50, height: 50)
                                    .rotationEffect(.degrees(spinAnimation ? 360 : 0))
                                    .animation(Animation.linear(duration: 1).repeatForever(autoreverses: false))
                                    .onAppear {
                                        self.spinAnimation = true
                                    }
                                    .padding()
            } else {
                TextViewDisplay(text: responseText)
                    .frame(height: 150)
                    .padding()
            }
            
            TextView(text: $text, placeholder: "#hashtags goes here!")
                .frame(height: 50)
                .padding()

            Button(action: {
                if(self.isLoading) {
                    return;
                }
                self.isLoading = true
                callOpenAI(prompt: text) { response in
                    self.responseText = response
                    self.isLoading = false
                }
            }) {
                Text("Draft Tweet")
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            .padding()
        }
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
