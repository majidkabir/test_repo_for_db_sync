SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_PackListByCtn08                                     */
/* Creation Date: 17-JAN-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose:  WMS-944 - CN SPEEDO CARTON LABEL CR                        */
/*        :                                                             */
/* Called By: r_dw_packing_list_by_ctn08                                */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 19-MAY-2021  CSCHONG   1.1 Temporary Rollback (CS01)                 */
/* 03-MAY-2021  CSCHONG   1.1 WMS-16902 - support multi order (CS01)    */
/* 19-MAY-2021  CSCHONG   1.2 WMS-16902 - Fix single order issue (CS02) */
/************************************************************************/
CREATE PROC [dbo].[isp_PackListByCtn08]
           @c_PickSlipNo      NVARCHAR(10)
         , @c_Orderkey        NVARCHAR(10) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt             INT
         , @n_Continue              INT
         
         , @n_PrintOrderAddresses   INT

           --CS01 START
          , @c_storerkey  NVARCHAR(20)
          , @c_loadkey    NVARCHAR(20)
          , @c_Company    NVARCHAR(45)
          , @n_CtnOrder   INT
        --CS01 END
          ,@c_MergeORD     NVARCHAR(1)  --CS02  

    CREATE TABLE #TMPPACKCTN08ORD
    ( Pickslipno    NVARCHAR(20)
     ,storerkey     NVARCHAR(20)
     ,loadkey       NVARCHAR(20)
     ,Orderkey      NVARCHAR(20)
     ,MergeORD      NVARCHAR(1)
    )
         
   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1

   SET @c_MergeORD = 'N'
   SET @n_CtnOrder = ''

   --CS02 START
    IF  EXISTS(SELECT 1 FROM PackHeader PH (nolock) WHERE PH.pickslipno=@c_PickSlipNo AND ISNULL(PH.OrderKey,'') = '')
    BEGIN
       SET @n_CtnOrder = 2
     --SET @c_MergeORD = 'Y'
      INSERT INTO #TMPPACKCTN08ORD
      (
          Pickslipno,
          storerkey,
          loadkey,
          Orderkey,
          MergeORD
      )
       SELECT PH.pickslipno,MAX(OH.storerkey),OH.loadkey,MAX(OH.orderkey),'Y'
       FROM PackHeader PH (nolock) 
       JOIN ORDERS OH WITH (NOLOCK) ON OH.LoadKey=PH.LoadKey
       WHERE PH.pickslipno=@c_PickSlipNo 
       GROUP BY PH.pickslipno,OH.loadkey
    END
    ELSE
    BEGIN

     SET @n_CtnOrder = 1 
     INSERT INTO #TMPPACKCTN08ORD
      (
          Pickslipno,
          storerkey,
          loadkey,
          Orderkey,
          MergeORD
      )
       SELECT PH.pickslipno,OH.storerkey,OH.loadkey,OH.orderkey,'N'
       FROM PackHeader PH (nolock) 
       JOIN ORDERS OH WITH (NOLOCK) ON OH.orderkey=PH.orderkey
       WHERE PH.pickslipno=@c_PickSlipNo 
    END
   --CS02 END

  	SELECT  dbo.ORDERS.Storerkey
         , CASE WHEN TPO.MergeORD='N' THEN TPO.Orderkey ELSE TPO.loadkey END    --CS02
         , ExternOrderkey= CASE WHEN TPO.MergeORD='N' THEN ISNULL(RTRIM(dbo.ORDERS.ExternOrderkey),'') ELSE '' END  --CS02
         , ConsigneeKey  = ISNULL(RTRIM(dbo.ORDERS.ConsigneeKey),'')
         , C_Company     = ISNULL(RTRIM(dbo.ORDERS.C_Company),'')
         , C_Address1    = ISNULL(RTRIM(dbo.ORDERS.C_Address1),'') 
         , C_Address2    = ISNULL(RTRIM(dbo.ORDERS.C_Address2),'')  
         , C_Address3    = ISNULL(RTRIM(dbo.ORDERS.C_Address3),'')  
         , C_Address4    = ISNULL(RTRIM(dbo.ORDERS.C_Address4),'') 
         , C_State       = ISNULL(RTRIM(dbo.ORDERS.C_State),'') 
         , C_City        = ISNULL(RTRIM(dbo.ORDERS.C_City),'') 
         , C_Contact1    = ISNULL(RTRIM(dbo.ORDERS.C_Contact1),'')
         , C_Contact2    = ISNULL(RTRIM(dbo.ORDERS.C_Contact2),'')         
         , C_Phone1      = ISNULL(RTRIM(dbo.ORDERS.C_Phone1),'') 
         , Customerpo    = ISNULL(RTRIM(dbo.ORDERS.UserDefine01),'') 
         , ORD_Notes     = ISNULL(RTRIM(dbo.ORDERS.Notes),'') 
         , dbo.PACKDETAIL.PickSlipNo
         , dbo.PACKDETAIL.CartonNo
         , dbo.PACKDETAIL.LabelNo
         , DropID        = ISNULL(RTRIM(dbo.PACKDETAIL.DropID),'') 
         , Material      = ISNULL(RTRIM(dbo.SKU.ManufacturerSku),'') 
         , Descr         = ISNULL(RTRIM(dbo.SKU.Notes1),'') 
         , Size          = ISNULL(RTRIM(dbo.SKU.Size),'') 
         , Qty           = SUM(dbo.PACKDETAIL.Qty) 
         , CtnOrder      = @n_CtnOrder                           --CS01
     FROM #TMPPACKCTN08ORD TPO (NOLOCK)                --CS02
     JOIN dbo.ORDERS WITH (NOLOCK)   
	    ON (TPO.Orderkey = dbo.ORDERS.Orderkey) 
     JOIN dbo.PACKDETAIL WITH (NOLOCK) 
	    ON (TPO.PickSlipNo = dbo.PACKDETAIL.PickSlipNo) 
     JOIN dbo.SKU WITH (NOLOCK) 
	    ON (dbo.PACKDETAIL.Storerkey = dbo.SKU.Storerkey) 
       AND(dbo.PACKDETAIL.Sku = dbo.SKU.Sku)
    WHERE (TPO.PickSlipNo= @c_PickSlipNo)
 GROUP BY dbo.ORDERS.Storerkey
        , CASE WHEN TPO.MergeORD='N' THEN TPO.Orderkey ELSE TPO.loadkey END    --CS02
        , CASE WHEN TPO.MergeORD='N' THEN ISNULL(RTRIM(dbo.ORDERS.ExternOrderkey),'') ELSE '' END --CS02
		  , ISNULL(RTRIM(dbo.ORDERS.ConsigneeKey),'')
	  	  , ISNULL(RTRIM(dbo.ORDERS.C_Company),'')
	  	  , ISNULL(RTRIM(dbo.ORDERS.C_Address1),'') 
	  	  , ISNULL(RTRIM(dbo.ORDERS.C_Address2),'')  
	  	  , ISNULL(RTRIM(dbo.ORDERS.C_Address3),'')  
	  	  , ISNULL(RTRIM(dbo.ORDERS.C_Address4),'') 
	  	  , ISNULL(RTRIM(dbo.ORDERS.C_State),'') 
	  	  , ISNULL(RTRIM(dbo.ORDERS.C_City),'')
	  	  , ISNULL(RTRIM(dbo.ORDERS.C_Contact1),'')         
	  	  , ISNULL(RTRIM(dbo.ORDERS.C_Contact2),'')    
	  	  , ISNULL(RTRIM(dbo.ORDERS.C_Phone1),'') 
        , ISNULL(RTRIM(dbo.ORDERS.UserDefine01),'') 
        , ISNULL(RTRIM(dbo.ORDERS.Notes),'') 
        , dbo.PACKDETAIL.PickSlipNo
        , dbo.PACKDETAIL.CartonNo
        , dbo.PACKDETAIL.LabelNo
        , ISNULL(RTRIM(dbo.PACKDETAIL.DropID),'') 
        , ISNULL(RTRIM(dbo.SKU.ManufacturerSku),'') 
        , ISNULL(RTRIM(dbo.SKU.Size),'') 
        , ISNULL(RTRIM(dbo.SKU.Notes1),'') 
 ORDER BY dbo.PACKDETAIL.CartonNo

QUIT_SP:
END -- procedure

GO