#include <dlfcn.h>
#include <nlohmann/json.hpp>
#include "customphrase-public.h"

typedef void *(*CustomPhraseCreate)();
typedef void (*CustomPhraseDestroy)(void *);
typedef void (*CustomPhraseLoad)(void *, const char *);
typedef void (*CustomPhraseSave)(void *, const char *);
typedef void (*CustomPhraseAdd)(void *, const char *, const char *, int);
typedef void (*CustomPhraseForeach)(
    void *, void (*)(const char *, const char *, int, void *), void *);

static void customphrase_foreach_callback(const char *key, const char *value,
                                          int order, void *userData) {
    auto *arr = static_cast<nlohmann::json *>(userData);
    arr->push_back(nlohmann::json::object({{"keyword", key},
                                           {"phrase", value},
                                           {"order", std::abs(order)},
                                           {"enabled", order > 0}}));
}

std::string customphrase_get(const char *path) noexcept {
    auto j = nlohmann::json::array();

    auto create = reinterpret_cast<CustomPhraseCreate>(
        dlsym(RTLD_DEFAULT, "customphrase_create"));
    auto load = reinterpret_cast<CustomPhraseLoad>(
        dlsym(RTLD_DEFAULT, "customphrase_load"));
    auto foreach = reinterpret_cast<CustomPhraseForeach>(
        dlsym(RTLD_DEFAULT, "customphrase_foreach"));
    auto destroy = reinterpret_cast<CustomPhraseDestroy>(
        dlsym(RTLD_DEFAULT, "customphrase_destroy"));

    if (create != nullptr && load != nullptr && foreach != nullptr &&
        destroy != nullptr) {
        void *dict = create();
        load(dict, path);
        foreach(dict, customphrase_foreach_callback, &j);
        destroy(dict);
    }

    return j.dump();
}

bool customphrase_set(const char *path, const char *json) noexcept {
    auto create = reinterpret_cast<CustomPhraseCreate>(
        dlsym(RTLD_DEFAULT, "customphrase_create"));
    auto add = reinterpret_cast<CustomPhraseAdd>(
        dlsym(RTLD_DEFAULT, "customphrase_add"));
    auto save = reinterpret_cast<CustomPhraseSave>(
        dlsym(RTLD_DEFAULT, "customphrase_save"));
    auto destroy = reinterpret_cast<CustomPhraseDestroy>(
        dlsym(RTLD_DEFAULT, "customphrase_destroy"));

    if (create == nullptr || add == nullptr || save == nullptr ||
        destroy == nullptr) {
        return false;
    }

    auto j = nlohmann::json::parse(json);
    void *dict = create();

    for (const auto &item : j) {
        auto order = item["order"].get<int>();
        if (!item["enabled"].get<bool>()) {
            order = -order;
        }
        add(dict, item["keyword"].get<std::string>().c_str(),
            item["phrase"].get<std::string>().c_str(), order);
    }

    save(dict, path);
    destroy(dict);
    return true;
}
