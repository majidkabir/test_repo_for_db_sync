SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_RPT_RP_DespLBL02                                    */
/* Creation Date: 2022-03-10                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: LFWM-3391 - MY-Convert Despatch Label to SCE                */
/*        : Convert to SCE - original Dw- r_dw_dispatch_label03         */
/* Called By: r_dw_rpt_rp_despllbl02                                    */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2022-03-10  Wan      1.0   Created & DevOps Combine Script           */
/************************************************************************/
CREATE   PROC [dbo].[isp_RPT_RP_DespLBL02]
     @c_Orderkey           NVARCHAR(10)   
   , @c_ExternOrderkey     NVARCHAR(30)   
   , @c_PickSlipNo         NVARCHAR(30)   
   , @n_PrintFrom          INT
   , @n_PrintTo            INT   
   , @c_LabelType          CHAR(1) = 'C'             
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT   = @@TRANCOUNT
         , @n_Continue        INT   = 1
         , @b_Success         INT   = 1
         , @c_ErrMsg          NVARCHAR(255) = '' 
         
         , @n_NoOfCase        INT   = 0
         , @n_NoOfPallet      INT   = 0
         , @n_NoOfLabel       INT   = 0   
         
   IF OBJECT_ID('tempdb..#TMP_DESPLBL','u') IS NOT NULL
   BEGIN
      DROP TABLE #TMP_DESPLBL;
   END  
   
   CREATE TABLE #TMP_DESPLBL
      (  RowID                INT            NOT NULL IDENTITY(1,1)  PRIMARY KEY
      ,  Orderkey             NVARCHAR(10)   NOT NULL DEFAULT('')
      ,  ExternOrderkey       NVARCHAR(30)   NOT NULL DEFAULT('')
      ,  Storerkey            NVARCHAR(15)   NOT NULL DEFAULT('')
      ,  ConsigneeKey         NVARCHAR(15)   NOT NULL DEFAULT('')  
      ,  [Route]              NVARCHAR(10)   NOT NULL DEFAULT('')
      ,  DeliveryDate         DATETIME       NULL   
      ,  C_Company            NVARCHAR(45)   NOT NULL DEFAULT('')
      ,  C_Address1           NVARCHAR(45)   NOT NULL DEFAULT('')
      ,  C_Address2           NVARCHAR(45)   NOT NULL DEFAULT('')
      ,  C_Address3           NVARCHAR(45)   NOT NULL DEFAULT('')
      ,  C_Address4           NVARCHAR(45)   NOT NULL DEFAULT('')
      ,  C_Zip                NVARCHAR(18)   NOT NULL DEFAULT('')
      ,  C_City               NVARCHAR(45)   NOT NULL DEFAULT('')
      ,  C_Country            NVARCHAR(30)   NOT NULL DEFAULT('')
      ,  ContainerQty         INT            NOT NULL DEFAULT(0)
      ,  InvoiceNo            NVARCHAR(20)   NOT NULL DEFAULT('')
      ,  BuyerPO              NVARCHAR(20)   NOT NULL DEFAULT('')
      ,  Notes2               NVARCHAR(255)  NOT NULL DEFAULT('')
      ,  PickHeaderKey        NVARCHAR(18)   NOT NULL DEFAULT('')
      ,  Destination          NVARCHAR(30)   NOT NULL DEFAULT('')
      ,  CartonNo             INT            NOT NULL DEFAULT(0)
      ,  ErrMsg               NVARCHAR(100)  NOT NULL DEFAULT('')
      )

   EXEC [dbo].[isp_RPT_RP_DespLBL_Std01]
        @c_Orderkey        = @c_Orderkey       OUTPUT  
      , @c_ExternOrderkey  = @c_ExternOrderkey 
      , @c_PickSlipNo      = @c_PickSlipNo     
      , @n_PrintFrom       = @n_PrintFrom      
      , @n_PrintTo         = @n_PrintTo        
      , @c_LabelType       = @c_LabelType      
      , @n_NoOfLabel       = @n_NoOfLabel      OUTPUT
      , @b_Success         = @b_Success        OUTPUT  
      , @c_ErrMsg          = @c_ErrMsg         OUTPUT  

   IF @b_Success = 0
   BEGIN
      GOTO QUIT_SP
   END
 
   ;WITH DL AS 
   (  SELECT CartonNo = @n_PrintFrom
         ,   Orderkey = @c_Orderkey
      UNION ALL
      SELECT CartonNo = DL.CartonNo + 1
         ,   Orderkey = @c_Orderkey
      FROM DL
      WHERE DL.CartonNo + 1 < @n_NoOfLabel + @n_PrintFrom
   )
   INSERT INTO #TMP_DESPLBL
       (
           Orderkey
       ,   ExternOrderkey
       ,   Storerkey
       ,   ConsigneeKey
       ,   [Route]
       ,   DeliveryDate
       ,   C_Company
       ,   C_Address1
       ,   C_Address2
       ,   C_Address3
       ,   C_Address4
       ,   C_Zip
       ,   C_City
       ,   C_Country
       ,   ContainerQty
       ,   InvoiceNo
       ,   BuyerPO        
       ,   Notes2         
       ,   PickHeaderKey  
       ,   Destination    
       ,   CartonNo
       )
   SELECT o.Orderkey
       ,  ExternOrderkey = ISNULL(o.ExternOrderkey,'')       
       ,  o.Storerkey      
       ,  ConsigneeKey   = ISNULL(o.ConsigneeKey  ,'')       
       ,  [Route]        = ISNULL(o.[Route]       ,'')       
       ,  o.DeliveryDate       
       ,  C_Company      = ISNULL(o.C_Company     ,'')       
       ,  C_Address1     = ISNULL(o.C_Address1    ,'')       
       ,  C_Address2     = ISNULL(o.C_Address2    ,'')       
       ,  C_Address3     = ISNULL(o.C_Address3    ,'')       
       ,  C_Address4     = ISNULL(o.C_Address4    ,'')       
       ,  C_Zip          = ISNULL(o.C_Zip         ,'')       
       ,  C_City         = ISNULL(o.C_City        ,'')       
       ,  C_Country      = ISNULL(o.C_Country     ,'')       
       ,  ContainerQty   = ISNULL(o.ContainerQty  ,0)       
       ,  InvoiceNo      = ISNULL(o.InvoiceNo     ,'')
       ,  BuyerPO        = ISNULL(o.BuyerPO      ,'')  
       ,  Notes2         = ISNULL(o.Notes2       ,'')  
       ,  PickHeaderKey  = ISNULL(p.PickHeaderKey,'')  
       ,  Destination    = ISNULL(ssd.Destination  ,'')
       ,  DL.CartonNo          
   FROM DL
   JOIN dbo.ORDERS AS o WITH (NOLOCK) ON o.OrderKey = DL.Orderkey
   LEFT OUTER JOIN dbo.PICKHEADER AS p WITH (NOLOCK) ON p.OrderKey = o.OrderKey
   LEFT OUTER JOIN dbo.StorerSODefault AS ssd WITH (NOLOCK) ON ssd.StorerKey = o.ConsigneeKey
   ORDER BY DL.CartonNo
   
QUIT_SP:
   IF @c_ErrMsg <> ''
   BEGIN
      INSERT INTO #TMP_DESPLBL ( ErrMsg )
      VALUES (@c_ErrMsg)
   END
   
   SELECT   td.RowID
         ,  td.Orderkey
         ,  td.ExternOrderkey
         ,  td.Storerkey
         ,  td.ConsigneeKey
         ,  td.[Route]
         ,  td.DeliveryDate
         ,  td.C_Company
         ,  td.C_Address1
         ,  td.C_Address2
         ,  td.C_Address3
         ,  td.C_Address4
         ,  td.C_Zip
         ,  td.C_City
         ,  td.C_Country
         ,  td.ContainerQty
         ,  td.InvoiceNo
         ,  td.BuyerPO           
         ,  td.Notes2            
         ,  td.PickHeaderKey     
         ,  td.Destination       
         ,  td.CartonNo
         ,  td.ErrMsg
   FROM #TMP_DESPLBL AS td
   ORDER BY td.RowID
END -- procedure

GO