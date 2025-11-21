SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: isp_loadmani_mbol07                                     */  
/* Creation Date: 16-Dec-2020                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose: WMS-15904 - SPZ Load Manifest                               */  
/*        :                                                             */  
/* Called By: r_dw_load_manifest_mbol07                                 */  
/*          :                                                           */  
/* GitLab Version: 1.0                                                  */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver Purposes                                  */ 
/************************************************************************/  
CREATE PROC [dbo].[isp_loadmani_mbol07]
            @c_MBOLKey    NVARCHAR(10)
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
         
         , @n_ShowDateReceived    INT = 0
         , @n_ShowSignature       INT = 0
         , @n_ShowReceivedBy      INT = 0
         , @n_ShowCompanyStamp    INT = 0
         , @n_ShowGRCheckedBy     INT = 0
         , @n_ShowGoodsReleasedBy INT = 0
         , @c_Storerkey           NVARCHAR(15) = ''

   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue  = 1  
   SET @b_Success   = 1  
   SET @n_Err       = 0  
   SET @c_Errmsg    = '' 
   
   SELECT @c_Storerkey = Storerkey
   FROM ORDERS (NOLOCK)
   WHERE MBOLKey = @c_MBOLKey
   
   SELECT @n_ShowDateReceived    = MAX(CASE WHEN ISNULL(CL.Code,'')  = 'ShowDateReceived'    THEN 1 ELSE 0 END)
        , @n_ShowSignature       = MAX(CASE WHEN ISNULL(CL.Code,'')  = 'ShowSignature'       THEN 1 ELSE 0 END)
        , @n_ShowReceivedBy      = MAX(CASE WHEN ISNULL(CL.Code,'')  = 'ShowReceivedBy'      THEN 1 ELSE 0 END)
        , @n_ShowCompanyStamp    = MAX(CASE WHEN ISNULL(CL.Code,'')  = 'ShowCompanyStamp'    THEN 1 ELSE 0 END)
        , @n_ShowGRCheckedBy     = MAX(CASE WHEN ISNULL(CL.Code,'')  = 'ShowGRCheckedBy'     THEN 1 ELSE 0 END)
        , @n_ShowGoodsReleasedBy = MAX(CASE WHEN ISNULL(CL.Code,'')  = 'ShowGoodsReleasedBy' THEN 1 ELSE 0 END)
   FROM CODELKUP CL (NOLOCK)
   WHERE CL.LISTNAME = 'REPORTCFG'
   AND CL.Long = 'r_dw_load_manifest_mbol07'
   AND CL.Storerkey = @c_Storerkey
   AND CL.Short = 'Y'

   /* For testing purpose
   SELECT @n_ShowDateReceived    = 1
        , @n_ShowSignature       = 1
        , @n_ShowReceivedBy      = 1
        , @n_ShowCompanyStamp    = 1
        , @n_ShowGRCheckedBy     = 1
        , @n_ShowGoodsReleasedBy = 1
   */
        
   SELECT ORDERDETAIL.OrderKey,
          ORDERDETAIL.StorerKey,
          ORDERS.ConsigneeKey,
          ORDERS.C_Company,
          ORDERS.C_Address1,
          ORDERS.C_Address2,
          ORDERS.C_Address3,
          ORDERS.C_Address4,
          ORDERS.C_City,
          ORDERS.C_Zip,
          MBOL.MbolKey,
          MBOL.DriverName,
          MBOL.AddDate,
          ORDERS.ExternOrderKey,
          ORDERS.InvoiceNo,
          Remarks=CONVERT(NVARCHAR(40), MBOL.Remarks),
          Cartons=MAX(ISNULL(PACKDETAIL.CartonNo,0)), 
          ORDERS.Deliverydate, 
          ORDERS.BUYERPO,
          MBOL.Facility,
          ISNULL(CL.Short,'N') as 'ShowBarCode',
          ISNULL(CL1.Short,'N') as 'ShowFacility',
          @n_ShowDateReceived    AS ShowDateReceived,   
          @n_ShowSignature       AS ShowSignature,      
          @n_ShowReceivedBy      AS ShowReceivedBy,    
          @n_ShowCompanyStamp    AS ShowCompanyStamp,   
          @n_ShowGRCheckedBy     AS ShowGRCheckedBy,    
          @n_ShowGoodsReleasedBy AS ShowGoodsReleasedBy
   FROM ORDERDETAIL (NOLOCK)   
   INNER JOIN ORDERS (NOLOCK) ON ( ORDERDETAIL.OrderKey = ORDERS.OrderKey )   
   INNER JOIN MBOL (NOLOCK) ON ( ORDERDETAIL.MBOLKey = MBOL.MbolKey )
   INNER JOIN MBOLDETAIL (NOLOCK) ON ( ORDERDETAIL.OrderKey = MBOLDETAIL.OrderKey ) 
   LEFT OUTER JOIN PACKHEADER (NOLOCK) ON ( ORDERS.OrderKey = PACKHEADER.OrderKey )
   LEFT OUTER JOIN PACKDETAIL (NOLOCK) ON ( PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo )
   LEFT JOIN CODELKUP CL WITH (NOLOCK) ON (CL.ListName = 'REPORTCFG' AND CL.Long = 'r_dw_load_manifest_mbol07'
                     AND CL.Code = 'SHOWBARCODE' AND CL.Storerkey = ORDERS.StorerKey)
   LEFT JOIN CODELKUP CL1 WITH (NOLOCK) ON (CL1.ListName = 'REPORTCFG' AND CL1.Long = 'r_dw_load_manifest_mbol07'
                     AND CL1.Code = 'SHOWFACILITY' AND CL1.Storerkey = ORDERS.StorerKey)
   WHERE ( MBOL.MbolKey = @c_MBOLKey )
   GROUP BY ORDERDETAIL.OrderKey,   
            ORDERDETAIL.StorerKey,
            ORDERS.ConsigneeKey,   
            ORDERS.C_Company,   
            ORDERS.C_Address1,   
            ORDERS.C_Address2,  
            ORDERS.C_Address3,
            ORDERS.C_Address4,
            ORDERS.C_City,
            ORDERS.C_Zip,     
            MBOL.MbolKey,
            MBOL.DriverName, 
            MBOL.AddDate,   
            ORDERS.ExternOrderKey, 
            ORDERS.InvoiceNo,
            CONVERT(NVARCHAR(40), MBOL.Remarks),
            ORDERS.Deliverydate,
            ORDERS.BUYERPO,
            MBOL.Facility,
            ISNULL(CL.Short,'N'),
            ISNULL(CL1.Short,'N') 
            
END -- procedure

GO