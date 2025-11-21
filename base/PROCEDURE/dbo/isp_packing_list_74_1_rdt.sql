SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: isp_Packing_List_74_1_rdt                               */  
/* Creation Date: 26-Mar-2021                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: mingle                                                   */  
/*                                                                      */  
/* Purpose: WMS-16570 - [KR] SouthCape_Invoice Report_DataWindow_CR     */  
/*        :                                                             */  
/* Called By: r_dw_packing_list_74_rdt                                  */  
/*          :                                                           */  
/* GitLab Version: 1.1                                                  */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver Purposes                                  */  
/************************************************************************/  
  
CREATE PROC [dbo].[isp_Packing_List_74_1_rdt]  
            @c_Orderkey     NVARCHAR(10)
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
  
         , @c_ExternOrderKey  NVARCHAR(50)  
         , @c_Storerkey       NVARCHAR(15)  

         , @c_RptLogo         NVARCHAR(255)  
         , @c_ecomflag        NVARCHAR(50)
         , @n_MaxLineno       INT
         , @n_MaxId           INT
         , @n_MaxRec          INT
         , @n_CurrentRec      INT
         , @c_recgroup        INT
  
   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue  = 1  
   SET @b_Success   = 1  
   SET @n_Err       = 0  
   SET @c_Errmsg    = '' 

   SELECT OH.Orderkey
        , OH.ExternOrderkey
        , CONVERT(NVARCHAR(10), GETDATE(), 102) AS TodayDate
        , OH.C_Company
        , LTRIM(RTRIM(ISNULL(OH.C_Address1,''))) + ' ' + LTRIM(RTRIM(ISNULL(OH.C_Address2,''))) AS C_Addresses
        , LTRIM(RTRIM(ISNULL(OH.C_Phone2,''))) AS C_Phone2
        , ISNULL(OH.Notes2,'') AS Notes2
        , ISNULL(St.SUSR1,'') AS STSUSR1
        , LTRIM(RTRIM(ISNULL(St.Address1,''))) + ' ' + LTRIM(RTRIM(ISNULL(St.Address2,''))) AS StAddresses
        , ISNULL(St.Zip,'') AS StZip
        --, PD.SKU
        --, ISNULL(OD.Notes,'') AS ODNotes
        --, ISNULL(OD.UserDefine01,'') AS UserDefine01
        --, ISNULL(OD.UserDefine02,'') AS UserDefine02
        --, SUM(PD.Qty) AS Qty
        --, OD.UnitPrice
        ----, ISNULL(St.LabelPrice,'') AS LabelPrice
        --, CASE WHEN OH.InvoiceAmount > 100000 THEN '0' ELSE ISNULL(St.LabelPrice,'') END AS LabelPrice   
        --, OH.InvoiceAmount
   FROM ORDERS OH (NOLOCK)
   JOIN STORER St (NOLOCK) ON St.Storerkey = OH.StorerKey
   --JOIN ORDERDETAIL OD (NOLOCK) ON OD.OrderKey = OH.OrderKey
   --JOIN PICKDETAIL PD (NOLOCK) ON PD.Orderkey = OH.OrderKey AND PD.SKU = OD.SKU AND PD.OrderLineNumber = OD.OrderLineNumber
   WHERE OH.OrderKey = @c_Orderkey
   GROUP BY OH.Orderkey
          , OH.ExternOrderkey
          , OH.C_Company
          , LTRIM(RTRIM(ISNULL(OH.C_Address1,''))) + ' ' + LTRIM(RTRIM(ISNULL(OH.C_Address2,'')))
          , LTRIM(RTRIM(ISNULL(OH.C_Phone2,'')))
          , ISNULL(OH.Notes2,'')
          , ISNULL(St.SUSR1,'')
          , LTRIM(RTRIM(ISNULL(St.Address1,''))) + ' ' + LTRIM(RTRIM(ISNULL(St.Address2,'')))
          , ISNULL(St.Zip,'')
          --, PD.SKU
          --, ISNULL(OD.Notes,'')
          --, ISNULL(OD.UserDefine01,'')
          --, ISNULL(OD.UserDefine02,'')
          --, OD.UnitPrice
          ----, ISNULL(St.LabelPrice,'')
          --, CASE WHEN OH.InvoiceAmount > 100000 THEN '0' ELSE ISNULL(St.LabelPrice,'') END   
          --, OH.InvoiceAmount

QUIT_SP:  
   IF @n_Continue = 3  
   BEGIN  
      IF @@TRANCOUNT > 0  
      BEGIN  
         ROLLBACK TRAN  
      END  
   END  
   ELSE  
   BEGIN  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END  
   END  
  
   WHILE @@TRANCOUNT < @n_StartTCnt  
   BEGIN  
      BEGIN TRAN  
   END  
   
END -- procedure


GO