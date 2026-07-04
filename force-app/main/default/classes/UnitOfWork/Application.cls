/**
 * Minimal application factory exposing ONLY the fflib Unit of Work.
 *
 * We vendored fflib's Unit of Work (fflib_SObjectUnitOfWork /
 * fflib_ISObjectUnitOfWork / fflib_IUnitOfWorkFactory — BSD-3-Clause, from
 * apex-enterprise-patterns/fflib-apex-common) instead of installing the whole
 * framework. This class is our own thin factory: it gives every caller a clean,
 * swappable entry point — `Application.UnitOfWork.newInstance()` — and a
 * `setMock` seam for tests, mirroring fflib_Application.UnitOfWorkFactory so a
 * later move to the full framework is a drop-in (same call sites).
 *
 * If you later adopt the Selector/Domain/Service factories too, rename or fold
 * this into a full `fflib_Application`-style class; the UnitOfWork member and
 * its call sites don't change.
 */
public class Application {
    /**
     * The Unit of Work factory. The SObjectType list is the DML/commit ORDER —
     * parents BEFORE children so lookup relationships resolve. Every object you
     * register with a UoW MUST appear here, or commitWork throws
     * "SObject type X is not supported by this unit of work". Add your custom
     * and other standard objects below in parent -> child order.
     *
     * FLS note: the default DML runs in SYSTEM mode (fflib's default). For
     * user-mode DML that enforces CRUD/FLS on commit (per our security rules),
     * pass a UserModeDML instance:
     *   Application.UnitOfWork.newInstance(new fflib_SObjectUnitOfWork.UserModeDML());
     * or change the default here.
     */
    public static final UnitOfWorkFactory UnitOfWork = new UnitOfWorkFactory(
        new List<SObjectType>{
            Account.SObjectType,
            Contact.SObjectType,
            Lead.SObjectType,
            Opportunity.SObjectType,
            Case.SObjectType,
            Task.SObjectType,
            Event.SObjectType
            // , Trade__c.SObjectType, Bot__c.SObjectType, ...  <-- add yours (parent -> child)
        });

    /**
     * Faithful re-implementation of fflib_Application.UnitOfWorkFactory (BSD-3),
     * carved out so we don't pull in the Service/Selector/Domain factories.
     * Implements the standard fflib_IUnitOfWorkFactory so call sites are
     * framework-compatible.
     */
    public virtual class UnitOfWorkFactory implements fflib_IUnitOfWorkFactory {
        protected List<SObjectType> m_objectTypes;
        protected fflib_SObjectUnitOfWork.IDML m_dml;
        protected fflib_ISObjectUnitOfWork m_mockUow;

        public UnitOfWorkFactory() {}

        public UnitOfWorkFactory(List<SObjectType> objectTypes) {
            m_objectTypes = objectTypes.clone();
        }

        public UnitOfWorkFactory(List<SObjectType> objectTypes, fflib_SObjectUnitOfWork.IDML dml) {
            this(objectTypes);
            m_dml = dml;
        }

        public virtual fflib_ISObjectUnitOfWork newInstance() {
            if (m_mockUow != null) return m_mockUow;
            if (m_dml != null) return new fflib_SObjectUnitOfWork(m_objectTypes, m_dml);
            return new fflib_SObjectUnitOfWork(m_objectTypes);
        }

        public virtual fflib_ISObjectUnitOfWork newInstance(fflib_SObjectUnitOfWork.IDML dml) {
            if (m_mockUow != null) return m_mockUow;
            return new fflib_SObjectUnitOfWork(m_objectTypes, dml);
        }

        public virtual fflib_ISObjectUnitOfWork newInstance(List<SObjectType> objectTypes) {
            if (m_mockUow != null) return m_mockUow;
            if (m_dml != null) return new fflib_SObjectUnitOfWork(objectTypes, m_dml);
            return new fflib_SObjectUnitOfWork(objectTypes);
        }

        public virtual fflib_ISObjectUnitOfWork newInstance(List<SObjectType> objectTypes, fflib_SObjectUnitOfWork.IDML dml) {
            if (m_mockUow != null) return m_mockUow;
            return new fflib_SObjectUnitOfWork(objectTypes, dml);
        }

        /**
         * Inject a mock Unit of Work for a test. Requires fflib-apex-mocks
         * (fflib_SObjectMocks.SObjectUnitOfWork) — not vendored here. Without the
         * mocks library, test services against real DML via commitWork instead.
         */
        @TestVisible
        private void setMock(fflib_ISObjectUnitOfWork mockUow) {
            m_mockUow = mockUow;
        }
    }
}
