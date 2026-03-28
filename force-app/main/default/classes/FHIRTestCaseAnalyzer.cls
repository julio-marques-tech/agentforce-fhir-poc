public with sharing class FHIRTestCaseAnalyzer {

    @InvocableMethod(
        label='Analyze FHIR Test Case'
        description='Validates a FHIR resource payload with deterministic rules for SNS Portugal certification'
        category='FHIR Validation'
    )
    public static List<AnalysisOutput> analyze(List<AnalysisInput> inputs) {
        List<AnalysisOutput> results = new List<AnalysisOutput>();

        for (AnalysisInput input : inputs) {
            AnalysisOutput output = new AnalysisOutput();
            List<String> violations = new List<String>();

            try {
                Map<String, Object> fhirResource =
                    (Map<String, Object>) JSON.deserializeUntyped(input.fhirPayload);

                if (!fhirResource.containsKey('resourceType'))
                    violations.add('FHIR-001: Campo "resourceType" é obrigatório');

                if (!fhirResource.containsKey('id'))
                    violations.add('FHIR-002: Campo "id" é obrigatório em todos os recursos');

                String resourceType = (String) fhirResource.get('resourceType');
                output.resourceType = resourceType != null ? resourceType : 'UNKNOWN';

                if ('Patient'.equals(resourceType)) {
                    violations.addAll(validatePatient(fhirResource));
                } else if ('Observation'.equals(resourceType)) {
                    violations.addAll(validateObservation(fhirResource));
                } else if ('Bundle'.equals(resourceType)) {
                    violations.addAll(validateBundle(fhirResource));
                } else if (resourceType != null) {
                    violations.add('FHIR-003: ResourceType "' + resourceType + '" não suportado nesta versão');
                }

                output.status         = violations.isEmpty() ? 'PASS' : 'FAIL';
                output.violations     = JSON.serialize(violations);
                output.violationCount = violations.size();
                output.summary        = buildSummary(output.status, violations);

            } catch (Exception e) {
                output.status         = 'ERROR';
                output.resourceType   = 'UNKNOWN';
                output.violations     = '["SYSTEM-001: Payload inválido - ' + e.getMessage() + '"]';
                output.violationCount = 1;
                output.summary        = 'Erro ao processar payload. Verifique se o JSON é válido.';
            }

            persistResult(input.testCaseId, input.fhirPayload, output);
            results.add(output);
        }
        return results;
    }

    private static List<String> validatePatient(Map<String, Object> r) {
        List<String> v = new List<String>();
        if (!r.containsKey('name'))
            v.add('FHIR-101: Patient.name é obrigatório');
        if (!r.containsKey('gender'))
            v.add('FHIR-102: Patient.gender é obrigatório (male|female|other|unknown)');
        if (!r.containsKey('birthDate'))
            v.add('FHIR-103: Patient.birthDate é obrigatório (formato YYYY-MM-DD)');
        else {
            String bd = (String) r.get('birthDate');
            if (!Pattern.matches('\\d{4}-\\d{2}-\\d{2}', bd))
                v.add('FHIR-104: Patient.birthDate com formato inválido. Use YYYY-MM-DD');
        }
        return v;
    }

    private static List<String> validateObservation(Map<String, Object> r) {
        List<String> v = new List<String>();
        if (!r.containsKey('status'))
            v.add('FHIR-201: Observation.status é obrigatório');
        if (!r.containsKey('code'))
            v.add('FHIR-202: Observation.code é obrigatório (LOINC/SNOMED)');
        if (!r.containsKey('subject'))
            v.add('FHIR-203: Observation.subject (referência ao Patient) é obrigatório');
        return v;
    }

    private static List<String> validateBundle(Map<String, Object> r) {
        List<String> v = new List<String>();
        if (!r.containsKey('type'))
            v.add('FHIR-301: Bundle.type é obrigatório (transaction|document|message)');
        if (!r.containsKey('entry'))
            v.add('FHIR-302: Bundle deve conter ao menos um entry');
        return v;
    }

    private static String buildSummary(String status, List<String> violations) {
        if (status == 'PASS') return 'Recurso FHIR válido. Nenhuma violação encontrada.';
        return violations.size() + ' violação(ões) encontrada(s). Revise os campos indicados.';
    }

    private static void persistResult(String testCaseId, String payload, AnalysisOutput output) {
        try {
            FHIR_Test_Result__c rec = new FHIR_Test_Result__c(
                Test_Case_Id__c  = testCaseId,
                Resource_Type__c = output.resourceType,
                Status__c        = output.status,
                Violations__c    = output.violations,
                Analyzed_At__c   = DateTime.now(),
                Raw_Payload__c   = payload
            );
            insert rec;
        } catch (Exception e) {
            System.debug('Erro ao persistir resultado: ' + e.getMessage());
        }
    }

    public class AnalysisInput {
        @InvocableVariable(label='FHIR Payload JSON' required=true)
        public String fhirPayload;

        @InvocableVariable(label='Test Case ID' required=true)
        public String testCaseId;
    }

    public class AnalysisOutput {
        @InvocableVariable(label='Status')
        public String status;

        @InvocableVariable(label='Resource Type')
        public String resourceType;

        @InvocableVariable(label='Violations JSON')
        public String violations;

        @InvocableVariable(label='Violation Count')
        public Integer violationCount;

        @InvocableVariable(label='Summary')
        public String summary;
    }
}