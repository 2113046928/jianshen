import UIKit

/// 动作实拍图（起始 / 结束两帧）。
///
/// 图片来自 free-exercise-db（Unlicense，公有领域），已缩放到 640px 内置在包里，
/// 不联网。没有收录实拍图的动作会回落到动作模式示意图。
enum ExercisePhotoStore {

    static func photos(for exerciseID: String) -> [UIImage] {
        ["0", "1"].compactMap { UIImage(named: "\(exerciseID)-\($0)") }
    }

    static func cover(for exerciseID: String) -> UIImage? {
        UIImage(named: "\(exerciseID)-0")
    }

    static func hasPhotos(_ exerciseID: String) -> Bool {
        UIImage(named: "\(exerciseID)-0") != nil
    }
}
