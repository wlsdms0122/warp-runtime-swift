//
//  Work.swift
//  WarpMacrosPlugin
//

import SwiftSyntax

// The Swift function a native procedure does its work in: the parameters a
// call hands it, the context it may take last, and what it returns.
struct Work {
    // One parameter a call hands: the Warp name it stands under, the label
    // the function is called with as Swift spells it, and its Swift type.
    struct Argument {
        // MARK: - Property
        let name: String
        let label: String?
        let type: String

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // MARK: - Property
    let parameters: [Argument]

    // Whether the function takes the context last, and the label it is
    // handed under there.
    let takesContext: Bool
    let contextLabel: String?

    // Nil where the function returns nothing.
    let returnType: String?

    let async: Bool
    let `throws`: Bool

    // Whether this is the protocol's own entry, which takes the context alone
    // and unlabeled.
    let isEntry: Bool

    // MARK: - Initializer
    init(_ function: FunctionDeclSyntax, context: String) {
        let all = Array(function.signature.parameterClause.parameters)
        let takesContext = all.last.map { parameter in TypeName(parameter.type).text == context } ?? false
        let handed = takesContext ? all.dropLast() : all[...]
        let returned = function.signature.returnClause?.type.trimmedDescription

        self.parameters = handed.map { parameter in
            let labeled = parameter.firstName.tokenKind != .wildcard
            let named = labeled ? parameter.firstName : parameter.secondName ?? parameter.firstName

            return Argument(
                name: named.identifier?.name ?? named.text,
                label: labeled ? parameter.firstName.text : nil,
                type: parameter.type.trimmedDescription
            )
        }
        self.takesContext = takesContext
        self.contextLabel = takesContext
            ? all.last.flatMap { parameter in parameter.firstName.tokenKind == .wildcard ? nil : parameter.firstName.text }
            : nil
        self.returnType = returned == "Void" || returned == "()" ? nil : returned
        self.async = function.signature.effectSpecifiers?.asyncSpecifier != nil
        self.throws = function.signature.effectSpecifiers?.throwsClause != nil
        self.isEntry = takesContext && all.count == 1 && all[0].firstName.tokenKind == .wildcard
    }

    // MARK: - Public
    // MARK: - Private
}
