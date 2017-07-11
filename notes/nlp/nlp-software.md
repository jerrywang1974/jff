# Natural Language Processing Software

* https://nlp.stanford.edu/software/
* http://www.nltk.org/
* https://spacy.io/
* https://github.com/clips/pattern
* http://opencyc.org/
* http://wordnet.princeton.edu/

## Comparison of Features

| Feature                                   | LTP | NLPIR | BosonNLP | CoreNLP | HanLP | THULAC   | Jieba | SnowNLP | spaCy | NLTK | TextBlob | Polyglot | Pattern |
|-------------------------------------------|-----|-------|----------|---------|-------|----------|-------|---------|-------|------|----------|----------|---------|
| Word Segmentation，分词                   | Y   | Y     | Y        | Y       | Y     | Y        | Y     | Y       | Y     | Y    | Y        | Y        | Y       |
| Part-of-speech Tagging, 词性标注          | Y   | Y     | Y        | Y       | Y     | Y        | Y     | Y       | Y     | Y    | Y        | Y        | Y       |
| Named Entity Recognition, 命名实体识别    | Y   |       | Y        | Y       | Y     |          |       |         | Y     | Y    | Y        | Y        |         |
| Dependency Parsing, 依存句法分析          | Y   |       | Y        | Y       | Y     |          |       |         | Y     | Y    | Y        |          | Y       |
| Semantic Role Labeling, 语义角色标注      | Y   |       |          |         |       |          |       |         |       |      |          |          | Y       |
| Semantic Dependency Parsing，语义依存分析 | Y   |       |          |         |       |          |       |         |       |      |          |          |         |
| Keyword Extraction，关键词提取            |     | Y     | Y        |         | Y     | (THUTAG) | Y     | Y       |       |      |          |          |         |
| Topic Classification，主题分类            |     |       | Y        |         |       | (THUCTC) |       |         |       | Y    |          |          |         |
| Sentiment Analysis，情感分析              |     |       | Y        | Y       |       |          |       | Y       |       | Y    | Y        | Y        | Y       |
| Summary，摘要                             |     |       | Y        |         | Y     |          |       | Y       |       |      |          |          |         |
| Similarity，相似度                        |     |       |          |         |       |          |       | Y       |       |      |          |          |         |
| Word Embedding，词向量                    |     |       |          |         |       |          |       |         |       |      |          | Y        | Y       |


## Word Segmenter

参考 https://www.zhihu.com/question/19578687 ，中文分词器有两种，
一种是基于词典做字符串正向、反向最大匹配，比如 paoding, ik, mmseg，
一种是基于统计模型如 HMM、CRF、SVM、deep learning。

* 基于词典
    * https://github.com/medcl/elasticsearch-analysis-mmseg 没有考虑停止词，自带词典比较小，算法质量不错，可能是停止词缘故，整体效果一般
    * https://github.com/medcl/elasticsearch-analysis-ik  得益于较大的词典，虽然算法不大好，歧义处理不好，但整体效果还行
    * https://github.com/ysc/word 杨尚川的中文分词项目，歧义比较多，WordSegmenter.segWithStopWords() + SegmentationAlgorithm.MinimalWordCount 效果较好；
    * https://www.elastic.co/guide/en/elasticsearch/plugins/5.4/analysis-smartcn.html 不支持定制
    * https://www.elastic.co/guide/en/elasticsearch/reference/current/analysis-lang-analyzer.html#cjk-analyzer  简单的 bi-gram 分词

* 基于统计模型
    * https://github.com/HIT-SCIR/ltp HIT(哈工大) LTP，质量非常高，商用收费
    * https://github.com/NLPIR-team/NLPIR  中科院 ICTCLAS / NLPIR, 基于 HMM 模型，商用收费
    * https://nlp.stanford.edu/software/segmenter.html 基于 CRF 模型，效果良好
    * https://github.com/hankcs/HanLP/ Java 版，功能全，Apache License，分词效果 StandardTokenizer < NLPTokenizer <  CRFSegment
    * https://github.com/thunlp/THULAC 清华大学 Lexical Analyzer for Chinese，商用收费，有一份很好的 LTP/ICTCLAS/THULAC/Jieba 的对比测试结果。只有分词以及词性分析，词性分析非常慢。
    * https://github.com/fxsjy/jieba 词典比较大，默认启用 HMM，效果比较好，只有分词、词性分析、关键词提取。
    * https://spacy.io 中文分词使用的 jieba
    * https://github.com/sloria/TextBlob Python 版，基于 [NLTK](http://www.nltk.org/) 和 [Pattern](https://github.com/clips/pattern)
    * https://github.com/isnowfy/snownlp Python 版，使用 HMM 模型，效果较好，功能比较丰富，但已不再积极维护
    * https://github.com/aboSamoor/polyglot Python 版，使用 ICU boundary break algorithm 分词
    * http://bosonnlp.com/ Web service，质量非常高，商用收费
    * https://github.com/NLPchina/ansj_seg 基于 n-gram/HMM/CRF，文档缺乏，分词质量还行。注意默认词典没有放入 jar 包，容易被使用者误解分词质量不行。
    * https://github.com/FudanNLP/fnlp 质量比较差
    * https://github.com/koth/kcws Deep Learning Chinese Word Segment
    * https://code.google.com/archive/p/nlpbamboo/ 使用 CRF 模型，已停止维护

