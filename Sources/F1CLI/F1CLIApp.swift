import Foundation

@main
struct F1CLIApp {
    static func main() async {
        await F1CLIRunner.run(arguments: CommandLine.arguments)
    }
}
