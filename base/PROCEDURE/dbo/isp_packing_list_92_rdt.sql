SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_packing_list_92_rdt                                 */
/* Creation Date: 03-Dec-2020                                           */
/* Copyright: LF Logistics                                              */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-15784 - GANT B2B Packing List                           */
/*        :                                                             */
/* Called By: r_dw_packing_list_92_rdt                                  */
/*          :                                                           */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_packing_list_92_rdt]
            @c_Pickslipno NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt       INT
         , @n_Continue        INT 
         , @c_Loadkey         NVARCHAR(10) = ''
         , @c_Orderkey        NVARCHAR(10) = ''
         , @n_Err             INT = 0
         , @c_ErrMsg          NVARCHAR(255) = ''
         , @b_success         INT = 1

   SELECT  PDET.CartonNo as CartonNo
         , OH.Orderkey as Orderkey
         , ISNULL(OH.C_Contact1,'') AS CContact1
         , ISNULL(OH.C_Address1,'') AS CAddress1
         , ISNULL(OH.C_Address2,'') AS CAddress2
         , ISNULL(OH.C_Address3,'') AS CAddress3
         , ISNULL(OH.C_Address4,'') AS CAddress4
         , ISNULL(OH.C_state,'')    AS CState
         , ISNULL(oh.C_city,'')     AS CCity
         , ISNULL(oh.C_phone1,'')   AS CPhone1
         , ISNULL(SKU.Color,'')     AS SColor
         , ISNULL(SKU.STYLE,'')     AS SSTYLE
         , SKU.AltSKU AS AltSKU
         , SKU.DESCR AS DESCR
         , ISNULL(SKU.Size,'') AS SSize
         , OH.Externorderkey as ExternOrderkey
         , SUM(PDET.Qty) as Qty
         , 'PCS' AS Unit
         , PH.PickSlipNo
   FROM PACKHEADER PH WITH (NOLOCK)
   JOIN PACKDETAIL PDET WITH (NOLOCK) ON (PDET.Pickslipno = PH.Pickslipno)
   JOIN ORDERS     OH WITH (NOLOCK) ON (PH.Orderkey = OH.Orderkey)
   JOIN SKU       SKU WITH (NOLOCK) ON (PDET.Storerkey = SKU.Storerkey)
                                   AND (PDET.Sku = SKU.Sku)
   WHERE PH.Pickslipno = @c_Pickslipno
   GROUP BY PDET.CartonNo
         , OH.Orderkey
         , ISNULL(OH.C_Contact1,'')
         , ISNULL(OH.C_Address1,'') 
         , ISNULL(OH.C_Address2,'') 
         , ISNULL(OH.C_Address3,'') 
         , ISNULL(OH.C_Address4,'') 
         , ISNULL(OH.C_State,'')
         , ISNULL(oh.C_City,'') 
         , ISNULL(oh.C_Phone1,'')
         , ISNULL(SKU.Color,'') 
         , ISNULL(SKU.STYLE,'') 
         , SKU.AltSKU
         , SKU.DESCR
         , ISNULL(SKU.Size,'')
         , OH.Externorderkey
         , PH.PickSlipNo
   ORDER BY PH.PickSlipNo, PDET.CartonNo

QUIT_SP:
   IF CURSOR_STATUS('LOCAL' , 'CUR_LOOP') in (0 , 1)
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP   
   END

   IF OBJECT_ID('tempdb..#TMP_Externorderkey') IS NOT NULL
   BEGIN
      DROP TABLE #TMP_Externorderkey
   END

   IF OBJECT_ID('tempdb..#TMP_DECRYPTEDDATA') IS NOT NULL
   BEGIN
      DROP TABLE #TMP_DECRYPTEDDATA
   END

   IF @n_continue=3  -- Error Occured - Process And Return  
    BEGIN  
       SELECT @b_success = 0  
       IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt  
       BEGIN  
          ROLLBACK TRAN  
       END  
       ELSE  
       BEGIN  
          WHILE @@TRANCOUNT > @n_starttcnt  
          BEGIN  
             COMMIT TRAN  
          END  
       END  
       execute nsp_logerror @n_err, @c_errmsg, "isp_packing_list_92_rdt"  
       RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
       RETURN  
    END  
    ELSE  
    BEGIN  
       SELECT @b_success = 1  
       WHILE @@TRANCOUNT > @n_starttcnt  
       BEGIN  
          COMMIT TRAN  
       END  
       RETURN  
    END
END -- procedure

GO