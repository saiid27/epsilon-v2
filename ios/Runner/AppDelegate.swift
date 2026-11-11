import Flutter
import UIKit
import UserNotifications
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, UIDocumentPickerDelegate {
  private var pendingFilePickerResult: FlutterResult?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "EpsilonNativeFilePicker") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "epsilon/file_picker",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard call.method == "pickFile" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard self?.pendingFilePickerResult == nil else {
        result(FlutterError(
          code: "busy",
          message: "يوجد اختيار ملف قيد التنفيذ.",
          details: nil
        ))
        return
      }
      let args = call.arguments as? [String: Any]
      let type = args?["type"] as? String ?? "image"
      self?.presentDocumentPicker(type: type, result: result)
    }
  }

  private func presentDocumentPicker(type: String, result: @escaping FlutterResult) {
    let allowedTypes = documentTypes(for: type)
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedTypes, asCopy: true)
    picker.delegate = self
    picker.allowsMultipleSelection = false
    pendingFilePickerResult = result

    guard let presenter = topViewController() else {
      pendingFilePickerResult = nil
      result(FlutterError(
        code: "no_presenter",
        message: "تعذر فتح اختيار الملف.",
        details: nil
      ))
      return
    }

    presenter.present(picker, animated: true)
  }

  private func documentTypes(for type: String) -> [UTType] {
    if type == "excel" {
      return [
        UTType(filenameExtension: "xlsx"),
        UTType(filenameExtension: "xlsm"),
        UTType(filenameExtension: "xls")
      ].compactMap { $0 }
    }
    return [.image]
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let result = pendingFilePickerResult else {
      return
    }
    pendingFilePickerResult = nil

    guard let url = urls.first else {
      result(nil)
      return
    }

    let fileName = url.lastPathComponent
    let destination = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension(url.pathExtension)

    do {
      try FileManager.default.copyItem(at: url, to: destination)
      result([
        "path": destination.path,
        "name": fileName
      ])
    } catch {
      result(FlutterError(
        code: "copy_failed",
        message: error.localizedDescription,
        details: nil
      ))
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    pendingFilePickerResult?(nil)
    pendingFilePickerResult = nil
  }

  private func topViewController() -> UIViewController? {
    let scene = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first { $0.activationState == .foregroundActive }
    let root = scene?.windows.first { $0.isKeyWindow }?.rootViewController ?? window?.rootViewController
    return topViewController(from: root)
  }

  private func topViewController(from controller: UIViewController?) -> UIViewController? {
    if let navigationController = controller as? UINavigationController {
      return topViewController(from: navigationController.visibleViewController)
    }
    if let tabController = controller as? UITabBarController {
      return topViewController(from: tabController.selectedViewController)
    }
    if let presented = controller?.presentedViewController {
      return topViewController(from: presented)
    }
    return controller
  }
}
