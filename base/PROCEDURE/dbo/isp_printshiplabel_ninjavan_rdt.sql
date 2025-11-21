SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: isp_PrintshipLabel_ninjavan_RDT                         */  
/* Creation Date: 26-OCT-2021                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: CSCHONG                                                  */  
/*                                                                      */  
/* Purpose: WMS-18104 - RG-Skechers_B2C_NinjaVan_ShippingLabel_Creation */  
/*        :                                                             */  
/* Called By: r_dw_print_shiplabel_ninjavan_rdt                         */  
/*          :                                                           */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver Purposes                                  */  
/* 27-OCT-2021 CSCHONG  1.1   Devops Scripts combine                    */
/************************************************************************/  
  
CREATE PROC [dbo].[isp_PrintshipLabel_ninjavan_RDT] 
            @c_externorderkey   NVARCHAR(20)
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE  
           @n_StartTCnt       INT  
         , @n_Continue        INT  
         , @b_Success         INT  
         , @n_Err             INT  
         , @c_Errmsg          NVARCHAR(255)  
  
         , @c_Storerkey       NVARCHAR(15)  

  
   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue  = 1  
   SET @b_Success   = 1  
   SET @n_Err       = 0  
   SET @c_Errmsg    = '' 

   SELECT ISNULL(OH.C_City,'') AS c_City
         , ISNULL(OH.C_State,'') AS c_state
         , OH.C_Contact1
         , OH.Externorderkey
         , OH.C_Address1 + ' ' + OH.C_Address2 + ' ' + OH.C_Address3 + ' ' + OH.C_Address4 AS CAddress
         , OH.C_Phone1         
         , OH.C_Phone2 
         , OH.Orderkey
         , ISNULL(OH.C_Zip,'') AS c_zip
         , OH.StorerKey
         , ISNULL(ST.Company,'') AS STCompany
         , ISNULL(OH.C_Company,'') AS C_Company
         , CONVERT(NVARCHAR(10),OH.Deliverydate,103) AS DELDate
         , ISNULL(OH.notes,'') AS OHNotes
         , OH.trackingno AS tackingno
         ,ISNULL(OH.Notes2,'') AS OHNotes2
   FROM ORDERS OH WITH (NOLOCK)
   JOIN STORER ST WITH (NOLOCK) ON ST.StorerKey=OH.StorerKey
   WHERE OH.ExternOrderKey = @c_externorderkey
   GROUP BY ISNULL(OH.C_City,'') ,
           ISNULL(OH.C_State,'')
          , OH.C_Contact1
          , OH.C_Address1 + ' ' + OH.C_Address2 + ' ' + OH.C_Address3 + ' ' + OH.C_Address4
          , OH.C_Phone1,oh.C_Phone2
          , OH.Externorderkey
          , CONVERT(NVARCHAR(10), OH.OrderDate, 101)
          , OH.Orderkey
          , ISNULL(OH.C_Zip,'')
          , oh.StorerKey, ISNULL(ST.Company,'')
          , CONVERT(NVARCHAR(10),OH.Deliverydate,103)
          , ISNULL(OH.notes,''), ISNULL(OH.notes2,'')
          , ISNULL(OH.C_Company,''), OH.TrackingNo
   ORDER BY OH.Orderkey

END -- procedure


GO