//
//  RecordingDetailView.swift
//  EchoVault
//
//  Created by Oluwadarasimi Oloyede on 19/01/2026.
//

import Foundation
import SwiftUI

struct RecordingDetailView: View{
    let filename: String
    let metadata: RecordingMetadata?
    
    var body: some View{
        List{
            if let meta = metadata{
                Section("Sentiment Analysis"){
                    HStack{
                        Text("Label:")
                        Spacer()
                        Text(meta.sentimentLabel.capitalized)
                            .foregroundColor(meta.sentimentLabel == "positive" ? .green: .red)
                    }
                }
                Section("Transcript"){
                    Text(meta.transcript)
                        .font(.body)
                        .padding(.vertical, 8)
                }
            }else{
                Text("Upload this recording to see the transcript and analysis.")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle(filename)
    }
}
