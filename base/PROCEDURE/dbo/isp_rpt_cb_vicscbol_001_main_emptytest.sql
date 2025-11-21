SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE   PROCEDURE [dbo].[isp_RPT_CB_VICSCBOL_001_Main_EmptyTest] 
(  
   @n_Cbolkey  BIGINT  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   SET ANSI_NULLS OFF  
  
   DECLARE @n_continue  INT = 1  
         , @n_StartTCnt INT = @@TRANCOUNT  
         , @n_ResultSize INT = 0

   SELECT @n_ResultSize = COUNT(*)
   FROM CBOL WITH (NOLOCK)  
   JOIN MBOL WITH (NOLOCK) ON (CBOL.CBOLKey = MBOL.CBOLKey)  
   JOIN FACILITY WITH (NOLOCK) ON (CBOL.Facility = FACILITY.Facility)  
   JOIN MBOLDETAIL WITH (NOLOCK) ON (MBOL.MbolKey = MBOLDETAIL.MbolKey)  
   JOIN ORDERS WITH (NOLOCK) ON (MBOLDETAIL.OrderKey = ORDERS.OrderKey)  
   LEFT OUTER JOIN STORER WITH (NOLOCK) ON (ORDERS.StorerKey = STORER.StorerKey)  
   LEFT OUTER JOIN STORER Storer2 WITH (NOLOCK) ON (CBOL.Consigneekey = Storer2.StorerKey)  
   --LEFT OUTER JOIN STORER Storer3 WITH (NOLOCK) ON (MBOL.OtherReference = Storer3.StorerKey) --(CLVN02) 
   LEFT OUTER JOIN STORER Storer3 WITH (NOLOCK) ON (MBOL.VoyageNumber = Storer3.StorerKey) 	   --(CLVN02) 
   LEFT OUTER JOIN STORER Storer4 WITH (NOLOCK) ON (CBOL.SCAC = Storer4.StorerKey)  
   LEFT OUTER JOIN CODELKUP CLK WITH (NOLOCK) ON (MBOL.TransMethod = CLK.Code AND CLK.LISTNAME = 'TRANSMETH')  
   WHERE CBOL.CBOLKey = @n_Cbolkey   
   AND ORDERS.[Status] >= '5'  

   IF @n_ResultSize = 0 RAISERROR('No records found for the given CBOLKey', 16, 1)

   SELECT CBOLKey = MAX(CBOL.CBOLKey)  
        , VoyageNumber = MAX(CBOL.VehicleContainer)   --WL01  
        , BookingReference = MAX(MBOL.BookingReference)  
        --, Remarks = MAX(CONVERT(NVARCHAR(2000), MBOL.Remarks))                                --(CLVN01)  
        , Remarks = MAX(CONCAT(TRIM(CONVERT(NVARCHAR(2000), MBOL.Remarks )), ' ' + TRIM(Storer2.Notes1))) --(CLVN01)  
        , UserDefine02 = ''   --MAX(ORDERS.UserDefine02)   --WL02
        , ConsigneeKey = MAX(CBOL.Consigneekey)  
        , C_Company  = MAX(ISNULL(TRIM(Storer2.Company), TRIM(ORDERS.C_Company)))  
        --, C_Address  = MAX(CONCAT(TRIM(ORDERS.C_Address1), TRIM(ORDERS.C_Address2), TRIM(ORDERS.C_Address3), TRIM(ORDERS.C_Address4)))                                                      --(CLVN01)  
        --, C_Address2 = MAX(CONCAT(TRIM(ORDERS.C_City), ', ' + TRIM(ORDERS.C_State), ', ' + TRIM(ORDERS.C_Zip)))                                                           --(CLVN01)  
        , C_Address  = CASE WHEN MAX(ISNULL(CBOL.CONSIGNEEKEY, '')) = '' THEN MAX(CONCAT(TRIM(ORDERS.C_Address1), TRIM(ORDERS.C_Address2), TRIM(ORDERS.C_Address3), TRIM(ORDERS.C_Address4))) --(CLVN01)  
                          ELSE MAX(CONCAT(TRIM(STORER2.Address1), TRIM(STORER2.Address2), TRIM(STORER2.Address3), TRIM(STORER2.Address4))) END                                   --(CLVN01)  
        , C_Address2 = CASE WHEN MAX(ISNULL(CBOL.CONSIGNEEKEY, '')) = '' THEN MAX(CONCAT(TRIM(ORDERS.C_City), ', ' + TRIM(ORDERS.C_State), ', ' + TRIM(ORDERS.C_Zip)))                    --(CLVN01)  
                          ELSE MAX(CONCAT(TRIM(STORER2.City), ', ' + TRIM(STORER2.State), ', ' + TRIM(STORER2.Zip))) END                                                     --(CLVN01)  
        , ShipAddress    = MAX(ISNULL(TRIM(FACILITY.Address1), ''))  
        , ShipAddress2   = MAX(CONCAT(TRIM(FACILITY.City), ', ' + TRIM(FACILITY.[State]), ', ' + TRIM(FACILITY.Zip)))  
        , Storer_Company = TRIM(MIN(STORER.Company)) + ' ' + MAX(ISNULL(RTRIM(FACILITY.UserDefine10), ''))  
        , TPAddress  = MAX(CONCAT(TRIM(Storer3.Address1), TRIM(Storer3.Address2), TRIM(Storer3.Address3), TRIM(Storer3.Address4)))  
        , TPAddress2 = MAX(CONCAT(TRIM(Storer3.City), ', ' + TRIM(Storer3.[State]), ', ' + TRIM(Storer3.Zip)))  
        , TPCompany  = MAX(ISNULL(TRIM(Storer3.Company), ''))  
        , m_userdefine01  = MAX(MBOL.UserDefine01)  
        , m_userdefine02  = MAX(MBOL.UserDefine02)  
        , m_userdefine03  = MAX(MBOL.UserDefine03)  
        , m_userdefine04  = MAX(MBOL.UserDefine04)  
        , m_userdefine05  = MAX(MBOL.UserDefine05)  
        , TransMethod     = MAX(MBOL.TransMethod)  
        , carrier_company = MAX(Storer4.Company)  
        , f_userdefine01  = MAX(FACILITY.UserDefine01)  
        , f_userdefine03  = MAX(FACILITY.UserDefine03)  
        , f_userdefine04  = MAX(FACILITY.UserDefine04)  
        , ContainerNo = MAX(CBOL.ProNumber)   --WL01  
        , SealNo = MAX(CBOL.SealNo)   --WL01  
        , CBOLReference = MAX(CBOL.CBOLKey)   --WL03
        , SCAC = MAX(CBOL.SCAC)  
   FROM CBOL WITH (NOLOCK)  
   JOIN MBOL WITH (NOLOCK) ON (CBOL.CBOLKey = MBOL.CBOLKey)  
   JOIN FACILITY WITH (NOLOCK) ON (CBOL.Facility = FACILITY.Facility)  
   JOIN MBOLDETAIL WITH (NOLOCK) ON (MBOL.MbolKey = MBOLDETAIL.MbolKey)  
   JOIN ORDERS WITH (NOLOCK) ON (MBOLDETAIL.OrderKey = ORDERS.OrderKey)  
   LEFT OUTER JOIN STORER WITH (NOLOCK) ON (ORDERS.StorerKey = STORER.StorerKey)  
   LEFT OUTER JOIN STORER Storer2 WITH (NOLOCK) ON (CBOL.Consigneekey = Storer2.StorerKey)  
   --LEFT OUTER JOIN STORER Storer3 WITH (NOLOCK) ON (MBOL.OtherReference = Storer3.StorerKey) --(CLVN02) 
   LEFT OUTER JOIN STORER Storer3 WITH (NOLOCK) ON (MBOL.VoyageNumber = Storer3.StorerKey) 	   --(CLVN02) 
   LEFT OUTER JOIN STORER Storer4 WITH (NOLOCK) ON (CBOL.SCAC = Storer4.StorerKey)  
   LEFT OUTER JOIN CODELKUP CLK WITH (NOLOCK) ON (MBOL.TransMethod = CLK.Code AND CLK.LISTNAME = 'TRANSMETH')  
   WHERE CBOL.CBOLKey = @n_Cbolkey   
   AND ORDERS.[Status] >= '5'  
END -- procedure
GO