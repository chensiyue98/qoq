import Foundation

@main
enum DictionaryDefinitionParserTests {
    static func main() {
        let raw = "crazy cra·zy | ˈkrāzē | informal adjective (crazier | ˈkrāzēər |) 1 very foolish, senseless, or strange: it was crazy to hope that good might come out of this mess | I'm always full of crazy ideas | the whole thing is crazy but I don't regret it. 2 extremely excited or enthusiastic."
        let layout = DictionaryDefinitionParser.parse(raw, term: "Crazy")

        guard layout.metadata == "cra·zy  ·  ˈkrāzē  ·  informal adjective (crazier  ·  ˈkrāzēər  ·  )" else {
            fatalError("Unexpected metadata: \(layout.metadata ?? "nil")")
        }
        guard layout.senses.count == 2,
              layout.senses[0].number == "1",
              layout.senses[0].definition.contains("\n• I'm always full of crazy ideas"),
              layout.senses[1].number == "2",
              layout.senses[1].definition == "extremely excited or enthusiastic." else {
            fatalError("Unexpected senses: \(layout.senses)")
        }

        let unstructured = DictionaryDefinitionParser.parse("a brief explanation", term: "word")
        guard unstructured.metadata == nil,
              unstructured.senses == [.init(number: nil, definition: "a brief explanation")] else {
            fatalError("Unstructured definitions should remain readable")
        }

        let bilingualRaw = "crazy • BrE ˈkreɪzi, AmE ˈkreɪzi • informal A. adjective ① (insane) 发疯的 fāfēng de▸ to go crazy 发疯▸ he would be crazy to do that 他要是那样做就真是疯了 ② (stupid) 愚蠢的 yúchǔn de ‹idea, behaviour›▸ to be crazy to do sth; 做某事是愚蠢的 ③ (enthusiastic) 狂热的 kuángrè de; (infatuated) 神魂颠倒的 shénhún diāndǎo de▸ to be crazy about sth; 对某事物很着迷 ④ (angry) 非常气愤的"
        let bilingual = DictionaryDefinitionParser.parse(bilingualRaw, term: "Crazy")
        guard bilingual.metadata?.contains("BrE ˈkreɪzi") == true,
              bilingual.metadata?.contains("informal A. adjective") == true,
              bilingual.senses.map(\.number) == ["1", "2", "3", "4"],
              bilingual.senses[0].definition.contains("\n• to go crazy 发疯") else {
            fatalError("Bilingual dictionary layout was not structured: \(bilingual)")
        }

        print("DictionaryDefinitionParser tests passed")
    }
}
