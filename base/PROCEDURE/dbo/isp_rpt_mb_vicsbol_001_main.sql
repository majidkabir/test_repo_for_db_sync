SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************************/ 
/* SP: isp_RPT_MB_VICSBOL_001_Main                                                     */ 
/* Creation Date: 18-Jun-2024                                                          */ 
/* Copyright: Maersk                                                                   */ 
/* Written by: WLChooi                                                                 */ 
/*                                                                                     */ 
/* Purpose: UWP-20706 - Granite | MWMS | BOL Report                                    */ 
/*        :                                                                            */ 
/* Called By: RPT_MB_VICSBOL_001_Main                                                  */ 
/*          :                                                                          */ 
/* Github Version: 1.8                                                                 */ 
/*                                                                                     */ 
/* Version: 7.0                                                                        */ 
/*                                                                                     */ 
/* Data Modifications:                                                                 */ 
/*                                                                                     */ 
/* Updates:                                                                            */ 
/* Date        Author   Ver   Purposes                                                 */ 
/* 18-Jun-2024 WLChooi  1.0   DevOps Combine Script                                    */ 
/* 01-Oct-2024 WLChooi  1.1   FCR-920 - Add new fields (WL01)                          */ 
/* 08-Oct-2024 CalvinK  1.2   FCR-956 - Change OtherReference to VoyageNumber (CLVN01) */ 
/* 09-Oct-2024 CalvinK  1.3   FCR-956 - ShipFrom Address mapping change (CLVN02)       */ 
/* 09-Oct-2024 WLChooi  1.4   FCR-968 - Change Mapping (WL02)                          */ 
/* 10-Oct-2024 GHUI     1.5   FCR-968 - Change Mapping (GH01)                          */  
/* 15-Oct-2024 CalvinK  1.6   FCR-995 - Change Remarks (CLVN03)                        */ 
/* 07-Nov-2024 WLChooi  1.7   FCR-1139 - Add Hardcoded Line based on Codelkup (WL03)   */
/* 05-Dec-2024 WLChooi  1.8   FCR-1459 Remove Userdefine02 - Not used (WL04)           */ 
/***************************************************************************************/ 
CREATE   PROCEDURE [dbo].[isp_RPT_MB_VICSBOL_001_Main]
( 
   @c_Mbolkey      NVARCHAR(10) 
 , @c_ConsigneeKey NVARCHAR(15) 
) 
AS 
BEGIN 
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF 
   SET ANSI_NULLS OFF 
 
   DECLARE @n_continue  INT = 1 
         , @n_StartTCnt INT = @@TRANCOUNT 
         , @c_Vics_MBOL NVARCHAR(50) = '' 
         , @c_BillToKey NVARCHAR(15) = ''   --WL03
         , @c_Storerkey NVARCHAR(15) = ''   --WL03
         , @n_LnExist   INT = 0   --WL03
 
   EXEC [dbo].[isp_GetVicsMbol] @c_Mbolkey = @c_Mbolkey 
                              , @c_Vics_MBOL = @c_Vics_MBOL OUTPUT 
 
   IF ISNULL(@c_Vics_MBOL, '') <> '' 
   BEGIN 
      UPDATE MBOL WITH (ROWLOCK) 
      SET ExternMBOLKey = IIF(ExternMBOLKey = @c_Vics_MBOL, ExternMBOLKey, @c_Vics_MBOL) 
        , TrafficCop = NULL 
      WHERE MBOLkey = @c_Mbolkey 
   END 
 
   IF ISNULL(@c_ConsigneeKey, '') = '' 
      SET @c_ConsigneeKey = '' 

   --WL03 S
   SELECT @c_BillToKey = ISNULL(BillToKey, '')
        , @c_Storerkey = StorerKey
   FROM ORDERS (NOLOCK)
   WHERE MBOLKey = @c_Mbolkey

   SET @n_LnExist = 0
   SELECT @n_LnExist = COUNT(1)
   FROM CODELKUP CL (NOLOCK)
   WHERE CL.LISTNAME = 'LVSCUSPREF'
   AND CL.[Description] = 'olpsplacement'
   AND CL.Storerkey = @c_Storerkey
   AND CL.Long IN ('2', '5')
   AND CL.code2 IN (@c_ConsigneeKey, @c_BillToKey)
   --WL03 E

   SELECT DISTINCT MBOL.MbolKey 
                 , MBOL.ExternMbolKey 
                 , VoyageNumber = MBOL.OtherReference 
                 , MBOL.Carrieragent 
                 , MBOL.DRIVERName 
                 , MBOL.VesselQualifier 
                 , MBOL.BookingReference 
                 --, Remarks = MAX(CONVERT(NVARCHAR(2000), MBOL.Remarks))                              --(CLVN03) 
                 , Remarks = CONCAT(TRIM(CONVERT(NVARCHAR(2000), MBOL.Remarks )), ' ' + TRIM(Storer2.Notes1)) --(CLVN03) 
                 , UserDefine02 = ''   --ORDERS.UserDefine02   --WL04
                 , ORDERS.ConsigneeKey 
                 , ShipCompany = ISNULL(TRIM(STORER.Company), '') + ' ' + ISNULL(RTRIM(FACILITY.UserDefine10), '') 
                -- , ShipAddress = ISNULL(TRIM(FACILITY.Descr), '')                                                                                    --(CLVN02)  
                -- , ShipAddress2 = CONCAT(TRIM(FACILITY.UserDefine01), ', ' + TRIM(FACILITY.UserDefine03), ', ' + TRIM(FACILITY.UserDefine04))        --(CLVN02)  
                 , ShipAddress = ISNULL(TRIM(FACILITY.Address1), '')                                                                                   --(CLVN02)  
                 , ShipAddress2 = CONCAT(TRIM(FACILITY.City), ', ' + TRIM(FACILITY.State), ', ' + TRIM(FACILITY.Zip))                                  --(CLVN02) 
                 , C_Company = ISNULL(TRIM(Storer2.Company), TRIM(ORDERS.C_Company)) 
                 , C_Address = CONCAT(TRIM(ORDERS.C_Address1), TRIM(ORDERS.C_Address2), TRIM(ORDERS.C_Address3), TRIM(ORDERS.C_Address4)) 
                 , C_Address2 = CONCAT(TRIM(ORDERS.C_City), ', ' + TRIM(ORDERS.C_State), ', ' + TRIM(ORDERS.C_Zip)) 
                 , TPCompany = ISNULL(TRIM(Storer3.Company), '') 
                 , TPAddress = CONCAT(TRIM(Storer3.Address1), TRIM(Storer3.Address2), TRIM(Storer3.Address3), TRIM(Storer3.Address4)) 
                 , TPAddress2 = CONCAT(TRIM(Storer3.City), ', ' + TRIM(Storer3.[State]), ', ' + TRIM(Storer3.Zip)) 
                 , (  SELECT COUNT(DISTINCT ORD2.ExternOrderKey) 
                      FROM MBOLDETAIL MD2 WITH (NOLOCK) 
                      JOIN ORDERS ORD2 WITH (NOLOCK) ON (MD2.OrderKey = ORD2.OrderKey) 
                      WHERE MD2.MbolKey = MBOL.MbolKey) AS DetailCnt 
                 , MBOL.OtherReference 
                 , MBOL.UserDefine01 AS m_userdefine01 
                 , MBOL.UserDefine02 AS m_userdefine02 
                 , MBOL.UserDefine03 AS m_userdefine03 
                 , MBOL.UserDefine04 AS m_userdefine04 
                 , MBOL.UserDefine05 AS m_userdefine05 
                 , MBOL.TransMethod 
                 , Storer4.Company AS carrier_company 
                 , MBOL.CarrierKey 
                 , ContainerNo = MBOL.Vessel   --WL02 
                 , MBOL.SealNo 
                 , LocationNo = ISNULL(ORDERS.C_contact1, '')   --WL01 
                 , CustomerNo = ISNULL(ORDERS.BillToKey, '')    --WL01
                 , PrnPLEnclosed = IIF(@n_LnExist > 0, 'Packing List Enclosed', '')   --WL03
   FROM MBOL WITH (NOLOCK) 
   JOIN FACILITY WITH (NOLOCK) ON (MBOL.Facility = FACILITY.Facility) 
   JOIN MBOLDETAIL WITH (NOLOCK) ON (MBOL.MbolKey = MBOLDETAIL.MbolKey) 
   JOIN ORDERS WITH (NOLOCK) ON (MBOLDETAIL.OrderKey = ORDERS.OrderKey) 
   LEFT OUTER JOIN STORER WITH (NOLOCK) ON (ORDERS.StorerKey = STORER.StorerKey) 
   LEFT OUTER JOIN STORER Storer2 WITH (NOLOCK) ON (ORDERS.ConsigneeKey = Storer2.StorerKey) 
   LEFT OUTER JOIN STORER Storer3 WITH (NOLOCK) ON (MBOL.VoyageNumber = Storer3.StorerKey) --(CLVN01) 
   LEFT OUTER JOIN STORER Storer4 WITH (NOLOCK) ON (MBOL.CarrierKey = Storer4.StorerKey) 
   LEFT OUTER JOIN CODELKUP CLK WITH (NOLOCK) ON (MBOL.TransMethod = CLK.Code AND CLK.LISTNAME = 'TRANSMETH') 
   WHERE MBOL.MbolKey = @c_Mbolkey  
   AND ORDERS.ConsigneeKey = @c_ConsigneeKey 
   AND ORDERS.[Status] >= '5' 
END -- procedure 

GO