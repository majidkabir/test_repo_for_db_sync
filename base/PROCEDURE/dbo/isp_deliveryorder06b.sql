SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: isp_DeliveryOrder06b                                        */
/* Creation Date: 19-SEP-2016                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: SOS#375875 - SG NIKE E-Com - Delivery Note                  */
/*        :                                                             */
/* Called By:  r_dw_delivery_order_06b                                  */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_DeliveryOrder06b] 
            @c_MBOLKey     NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1

   SELECT ExternMBOLKey = ISNULL(RTRIM(MBOL.ExternMBOLKey),'')
         ,MBOL.EditDate
         ,Orderkey = MAX(ORDERS.Orderkey)
         ,C_Company  = ISNULL(RTRIM(ORDERS.C_Company),'')
         --,C_Address1 = ISNULL(RTRIM(ORDERS.C_Address1),'')
         ,C_Address1 = ISNULL(RTRIM(ADDR.Long),'')
         ,C_Address2 = ''--ISNULL(RTRIM(ORDERS.C_Address2),'')
         ,C_Address3 = ''--ISNULL(RTRIM(ORDERS.C_Address3),'')
         ,C_Address4 = ''--ISNULL(RTRIM(ORDERS.C_Address4),'')
         ,C_City     = ''--ISNULL(RTRIM(ORDERS.C_City),'')
         ,C_Country  = ''--ISNULL(RTRIM(ORDERS.C_Country),'')
         ,Addr_remark= CASE WHEN ISNULL(RTRIM(ORDERS.C_ISOCNTRYCode),'') = 'SGP' 
                            THEN ''
                            ELSE 'Goods Delivered Are For Export'
                            END

         ,PALLETDETAIL.Palletkey
         ,Qty = COUNT(DISTINCT PALLETDETAIL.Palletkey) --SUM(PALLETDETAIL.Qty)
         ,NoOfCaseID = COUNT(CaseID)
         ,RouteCode  = ISNULL(RTRIM(PALLETDETAIL.Userdefine01),'')
   FROM MBOL          WITH (NOLOCK)
   JOIN ORDERS        WITH (NOLOCK) ON (MBOL.MBOLkey = ORDERS.MBOLkey)
   JOIN PALLETDETAIL  WITH (NOLOCK) ON (ORDERS.Orderkey = PALLETDETAIL.UserDefine02)
   LEFT JOIN CODELKUP ADDR WITH (NOLOCK) ON (ADDR.ListName = 'ISOCOUNTRY')
                                         AND(ADDR.Code = ISNULL(RTRIM(ORDERS.C_ISOCNTRYCode),''))
   WHERE MBOL.MBOLKey = @c_MBOLKey
   AND ORDERS.Type = 'Z033'
   GROUP BY ISNULL(RTRIM(MBOL.ExternMBOLKey),'')
         ,  MBOL.EditDate
         --,  ORDERS.Orderkey
         ,  ISNULL(RTRIM(ORDERS.C_Company),'')
         --,  ISNULL(RTRIM(ORDERS.C_Address1),'')
         --,  ISNULL(RTRIM(ORDERS.C_Address2),'')
         --,  ISNULL(RTRIM(ORDERS.C_Address3),'')
         --,  ISNULL(RTRIM(ORDERS.C_Address4),'')
         --,  ISNULL(RTRIM(ORDERS.C_City),'')
         --,  ISNULL(RTRIM(ORDERS.C_Country),'')
         ,  ISNULL(RTRIM(ORDERS.C_ISOCNTRYCode),'')
         ,  ISNULL(RTRIM(ADDR.Long),'')
         ,  PALLETDETAIL.Palletkey
         ,  ISNULL(RTRIM(PALLETDETAIL.Userdefine01),'')

QUIT_SP:
END -- procedure

GO