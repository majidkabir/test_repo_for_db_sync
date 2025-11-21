SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_UCC_Carton_Label_21f                                */
/* Creation Date: 17-JAN-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose:  WMS-944 - CN SPEEDO CARTON LABEL CR                        */
/*        :                                                             */
/* Called By: r_dw_ucc_carton_label_21f                                 */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 17-Jun-2019  WLCHOOI   1.1 WMS-9436 - New LabelNo Barcode (WL01)     */
/* 03-MAY-2021  CSCHONG   1.2 WMS-16901 - support multi order (CS01)    */
/* 19-MAY-2021  CSCHONG   1.3 WMS-16901 - Fix single order issue (CS02) */
/************************************************************************/
CREATE PROC [dbo].[isp_UCC_Carton_Label_21f]
           @c_Storerkey       NVARCHAR(15)
         , @c_PickSlipNo      NVARCHAR(10)
         , @c_StartCartonNo   NVARCHAR(10)
         , @c_EndCartonNo     NVARCHAR(10)
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
          , @c_loadkey    NVARCHAR(20)
          , @c_Company    NVARCHAR(45)
          , @n_CtnOrder   INT

        --CS01 END
          ,@c_MergeORD     NVARCHAR(1)  --CS02  


    CREATE TABLE #TMPPACKORD
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
    IF  EXISTS(SELECT 1 FROM PackHeader PH (nolock) WHERE PH.StorerKey=@c_Storerkey AND PH.pickslipno=@c_PickSlipNo AND ISNULL(PH.OrderKey,'') = '')
    BEGIN
       SET @n_CtnOrder = 2
     --SET @c_MergeORD = 'Y'
      INSERT INTO #TMPPACKORD
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
       WHERE PH.StorerKey=@c_Storerkey AND PH.pickslipno=@c_PickSlipNo 
       GROUP BY PH.pickslipno,OH.loadkey
    END
    ELSE
    BEGIN

       SET @n_CtnOrder = 1
       INSERT INTO #TMPPACKORD
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
       WHERE PH.StorerKey=@c_Storerkey AND PH.pickslipno=@c_PickSlipNo 
    END
   --CS02 END

   SELECT dbo.ORDERS.Storerkey
        , CASE WHEN TPO.MergeORD='N' THEN TPO.Orderkey ELSE TPO.loadkey END                                            --CS02
        , ExternOrderkey=  CASE WHEN TPO.MergeORD='N' THEN ISNULL(RTRIM(dbo.ORDERS.ExternOrderkey),'') ELSE '' END     --CS02
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
        , dbo.PACKDETAIL.PickSlipNo
        , dbo.PACKDETAIL.CartonNo
        , dbo.PACKDETAIL.LabelNo
        , DropID        = ISNULL(RTRIM(dbo.PACKDETAIL.DropID),'') 
        , Qty           = (SELECT SUM(Qty) FROM PACKDETAIL PCK WITH (NOLOCK) 
                           WHERE PCK.PickSlipNo = dbo.PACKDETAIL.PickSlipNo
                           AND   PCK.CartonNo = dbo.PACKDETAIL.CartonNo)
        , NewLabelNo    = CASE WHEN ISNULL(CL.SHORT,'N') = 'Y' AND CAST(CL.LONG AS INT) <> 0 THEN        --WL01
                          CL.UDF01 + RIGHT(REPLICATE('0',CL.LONG) + SUBSTRING(dbo.PACKDETAIL.LabelNo,CAST(CL.UDF02 AS INT),CAST(CL.UDF03 AS INT)-CAST(CL.UDF02 AS INT)+1) --WL01
                         ,CAST(CL.LONG AS INT)-LEN(CL.UDF01))
                          WHEN ISNULL(CL.SHORT,'N') = 'Y' AND CAST(CL.LONG AS INT) = 0 THEN              --WL01
                          CL.UDF01 + dbo.PACKDETAIL.LabelNo                                              --WL01
                          ELSE '' END                                                                    --WL01
          ,  CtnOrder = @n_CtnOrder                                                                               --CS01 
     FROM #TMPPACKORD TPO--dbo.PACKHEADER WITH (NOLOCK) 
     JOIN dbo.ORDERS WITH (NOLOCK)   
       ON (TPO.Orderkey = dbo.ORDERS.Orderkey) 
     JOIN dbo.PACKDETAIL WITH (NOLOCK) 
       ON (TPO.PickSlipNo = dbo.PACKDETAIL.PickSlipNo) 
     OUTER APPLY (SELECT TOP 1 CL.SHORT, CL.LONG, CL.UDF01, CL.UDF02, CL.UDF03, CL.CODE2 FROM
                  CODELKUP CL WITH (NOLOCK) WHERE (CL.LISTNAME = 'BARCODELEN' AND CL.STORERKEY = ORDERS.STORERKEY AND CL.CODE = 'SUPERHUB' AND
                 (CL.CODE2 = ORDERS.FACILITY OR CL.CODE2 = '') ) ORDER BY CASE WHEN CL.CODE2 = '' THEN 2 ELSE 1 END ) AS CL
    WHERE (TPO.PickSlipNo= @c_PickSlipNo)
      AND (TPO.Storerkey = @c_Storerkey)
      AND (dbo.PACKDETAIL.CartonNo BETWEEN @c_StartCartonNo AND @c_EndCartonNo)
 GROUP BY dbo.ORDERS.Storerkey
        , CASE WHEN TPO.MergeORD='N' THEN TPO.Orderkey ELSE TPO.loadkey END                       --CS02
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
        , dbo.PACKDETAIL.PickSlipNo
        , dbo.PACKDETAIL.CartonNo
        , dbo.PACKDETAIL.LabelNo
        , ISNULL(RTRIM(dbo.PACKDETAIL.DropID),'') 
        , ISNULL(CL.SHORT,'N')
        , CL.LONG       --WL01
        , CL.UDF01      --WL01
        , CL.UDF02      --WL01
        , CL.UDF03      --WL01
 ORDER BY dbo.PACKDETAIL.CartonNo

QUIT_SP:
END -- procedure

GO