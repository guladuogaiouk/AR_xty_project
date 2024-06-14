import SwiftUI
import RealityKit
import AVFoundation

struct ContentView: View {
    let videos: [String] = ["1", "2", "3"]
    @State var pics: [UIImage?] = []
    @State var selectedVideo: String = ""

    var body: some View {
        ZStack(alignment: .bottom) {
            ARViewContainer(selectedVideo: $selectedVideo)
                .edgesIgnoringSafeArea(.all)
            ScrollView(.horizontal) {
                HStack {
                    ForEach(pics.indices, id: \.self) { index in
                        if let pic = pics[index] {
                            Image(uiImage: pic)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 160, height: 90)
                                .onTapGesture {
                                    selectedVideo = videos[index]
                                }
                        } else {
                            Text("Failed to load video frame.")
                        }
                    }
                }
            }
            .background(Color.black.opacity(0.5))
        }
        .onAppear {
            loadFirstFrameImages()
        }
    }

    func loadFirstFrameImages() {
        pics.removeAll()
        for video in videos {
            if let image = getFirstFrameImageFromVideo(videoFilename: video) {
                pics.append(image)
            } else {
                pics.append(nil)
            }
        }
    }

    func getFirstFrameImageFromVideo(videoFilename: String) -> UIImage? {
        guard let videoURL = Bundle.main.url(forResource: videoFilename, withExtension: "mp4") else {
            print("Video file not found.")
            return nil
        }

        let asset = AVAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true

        do {
            let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            print("Error generating thumbnail: \(error.localizedDescription)")
            return nil
        }
    }
}


struct ARViewContainer: UIViewRepresentable {
    @Binding var selectedVideo: String

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        context.coordinator.arView = arView
        spawnTV(in: arView)
        arView.enableTapGesture(coordinator: context.coordinator)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.selectedVideo = selectedVideo
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: ARViewContainer
        var arView: ARView?
        var selectedVideo: String

        init(_ parent: ARViewContainer) {
            self.parent = parent
            self.selectedVideo = parent.selectedVideo
        }

        @objc func handleTap(recognizer: UITapGestureRecognizer) {
            guard let arView = arView else { return }
            let tapLocation = recognizer.location(in: arView)
            if let entity = arView.entity(at: tapLocation) as? ModelEntity, entity.name == "tvScreen" {
                loadVideoMaterial(for: entity)
            }
        }

        func loadVideoMaterial(for entity: ModelEntity) {
            if let currentVideoMaterial = entity.model?.materials.first as? VideoMaterial,
               let currentPlayer = currentVideoMaterial.avPlayer {
                if currentPlayer.timeControlStatus == .playing {
                    currentPlayer.pause()
                    return
                }
            }
            guard let videoURL = Bundle.main.url(forResource: selectedVideo, withExtension: "mp4") else {
                print("Video file not found.")
                return
            }
            let asset = AVAsset(url: videoURL)
            let playerItem = AVPlayerItem(asset: asset)
            let player = AVPlayer()
            entity.model?.materials = [VideoMaterial(avPlayer: player)]
            player.replaceCurrentItem(with: playerItem)
            player.play()
        }
    }

    func spawnTV(in arView: ARView) {
        let dimensions: SIMD3<Float> = [1.23/2, 0.046/2, 0.7/2]
        let housingMesh = MeshResource.generateBox(size: dimensions)
        let housingMat = SimpleMaterial(color: .black, roughness: 0.4, isMetallic: false)
        let housingEntity = ModelEntity(mesh: housingMesh, materials: [housingMat])
        let screenMesh = MeshResource.generatePlane(width: dimensions.x, depth: dimensions.z)
        let screenMat = SimpleMaterial(color: .black, roughness: 0.2, isMetallic: false)
        let screenEntity = ModelEntity(mesh: screenMesh, materials: [screenMat])
        screenEntity.name = "tvScreen"
        housingEntity.addChild(screenEntity)
        screenEntity.setPosition([0, dimensions.y/2 + 0.001, 0], relativeTo: housingEntity)
        let anchor = AnchorEntity(plane: .vertical)
        anchor.addChild(housingEntity)
        arView.scene.addAnchor(anchor)
        housingEntity.generateCollisionShapes(recursive: true)
    }
}

extension ARView {
    func enableTapGesture(coordinator: ARViewContainer.Coordinator) {
        let tapGestureRecognizer = UITapGestureRecognizer(target: coordinator, action: #selector(coordinator.handleTap(recognizer:)))
        self.addGestureRecognizer(tapGestureRecognizer)
    }
}
