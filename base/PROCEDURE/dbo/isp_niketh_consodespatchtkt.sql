SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_niketh_ConsoDespatchTkt                        */
/* Creation Date: 13-Jul-2022                                           */      
/* Copyright: LFL                                                       */      
/* Written by: WLChooi                                                  */  
/*                                                                      */
/* Purpose: WMS-20204 - TH-Nike-CR Picking label                        */   
/*                                                                      */
/* Called By: r_dw_despatch_ticket_nikeph                               */
/*            modified from isp_nikeph_ConsoDespatchTkt                 */
/*                          r_dw_despatch_ticket_nikeph                 */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 13-Jul-2022  WLChooi  1.0  DevOps Combine Script                     */ 
/************************************************************************/
CREATE PROC [dbo].[isp_niketh_ConsoDespatchTkt] (       
      @c_Pickslipno     NVARCHAR(10)    
    , @c_FromCartonNo   NVARCHAR(5)  = '' 
    , @c_ToCartonNo     NVARCHAR(5)  = ''
    , @c_FromLabelNo    NVARCHAR(20) = ''  
    , @c_ToLabelNo      NVARCHAR(20) = ''
    , @c_DropID         NVARCHAR(20) = ''
)      
AS
BEGIN

   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_getOrderkey     NVARCHAR(30)
         , @c_LoadKey         NVARCHAR(10)
         , @i_ExtCnt          INT
         , @i_LineCnt         INT
         , @n_CartonNo        INT
         , @n_SumPackQty      INT
         , @n_SumPickQty      INT
         , @c_ConsigneeKey    NVARCHAR(15)
         , @c_Company         NVARCHAR(45)
         , @c_Address1        NVARCHAR(45)
         , @c_Address2        NVARCHAR(45)
         , @c_Address3        NVARCHAR(45)
         , @c_Address4        NVARCHAR(45)
         , @c_City            NVARCHAR(45)
         , @d_DeliveryDate    DATETIME
         , @c_Orderkey        NVARCHAR(10)  
         , @c_Storerkey       NVARCHAR(15)             
         , @c_ShowQty_Cfg     NVARCHAR(10)             
         , @c_ShowOrdType_Cfg NVARCHAR(10)              
         , @c_susr4           NVARCHAR(10)             
         , @c_Stop            NVARCHAR(10)
         , @c_showfield       NVARCHAR(1)           
         , @c_showCRD         NVARCHAR(1)  
         , @c_BU              NVARCHAR(5)  
         , @c_Gender          NVARCHAR(20)
         , @c_category        NVARCHAR(30) 
         , @d_editdate        DATETIME
         , @c_GetPickslipno   NVARCHAR(20) = ''

   SET @c_Storerkey  = ''                            
   SET @c_ShowQty_Cfg= ''                             
   SET @c_ShowOrdType_Cfg = ''                        
   SET @c_susr4         = ''                         
   SET @c_showfield = 'N'                              
   SET @c_showCRD   = '' 

   IF ISNULL(@c_FromCartonNo,'') = '' OR ISNULL(@c_ToCartonNo,'') = ''
   BEGIN
      SELECT @c_FromCartonNo  = MIN(PD.CartonNo)
           , @c_ToCartonNo    = MAX(PD.CartonNo)
      FROM PACKDETAIL PD (NOLOCK)
      WHERE PD.PickSlipNo = @c_Pickslipno
      AND PD.LabelNo BETWEEN @c_FromLabelNo AND @c_ToLabelNo
   END

   IF ISNULL(@c_FromLabelNo,'') = '' OR ISNULL(@c_ToLabelNo,'') = ''
   BEGIN
      SELECT @c_FromLabelNo   = MIN(PD.LabelNo)
           , @c_ToLabelNo     = MAX(PD.LabelNo)
      FROM PACKDETAIL PD (NOLOCK)
      WHERE PD.PickSlipNo = @c_Pickslipno
      AND PD.CartonNo BETWEEN @c_FromCartonNo AND @c_ToCartonNo
   END

   IF OBJECT_ID('tempdb..#RESULT ','u') IS NOT NULL 
      DROP TABLE #RESULT 

   CREATE TABLE #RESULT(
       PickSlipNo      NVARCHAR(10) NULL,
       LoadKey         NVARCHAR(10) NULL,
       ConsigneeKey    NVARCHAR(15) NULL,
       C_Company       NVARCHAR(45) NULL,
       C_Address1      NVARCHAR(45) NULL,
       C_Address2      NVARCHAR(45) NULL,
       C_Address3      NVARCHAR(45) NULL,
       C_Address4      NVARCHAR(45) NULL,
       CartonNo        INT NULL,
       TotalPcs        INT NULL,
       CRD             DATETIME NULL,
       EditDate        DATETIME NULL,
       ExternOrderKey  NVARCHAR(50) NULL,
       C_City          NVARCHAR(45) NULL,
       ExternPOKey     NVARCHAR(20) NULL,
       Wavekey         NVARCHAR(10) NULL,
       LabelNo         NVARCHAR(20) NULL, 
       TotalCarton     INT NULL
   )

   CREATE INDEX IX_RESULT_01 on #RESULT ( LoadKey )
   CREATE INDEX IX_RESULT_02 on #RESULT ( CartonNo )

   INSERT INTO #RESULT
   SELECT PH.Pickslipno AS Pickslipno
        , ORD.Loadkey AS Loadkey
        , ISNULL(MAX(ORD.Consigneekey),'') as ConsigneeKey
        , ISNULL(MAX(ORD.C_Company),'') as C_Company
        , ISNULL(MAX(ORD.C_Address1),'') as C_Address1
        , ISNULL(MAX(ORD.C_Address2),'') as C_Address2
        , ISNULL(MAX(ORD.C_Address3),'') as C_Address3
        , ISNULL(MAX(ORD.C_Address4),'') as C_Address4
        , PAD.CartonNo AS CartonNo
        , 0 AS TotalPCS
        , ORD.DeliveryDate AS CRD
        , '' AS EditDate
        , ORD.ExternOrderKey AS Externorderkey
        , ISNULL(MAX(ORD.C_City),'') AS C_City
        , ISNULL(MAX(ORD.ExternPOKey),'') AS ExternPOKey
        , ORD.UserDefine09
        , PAD.LabelNo
        , (SELECT COUNT(DISTINCT PACKDETAIL.LabelNo) FROM PACKDETAIL (NOLOCK) 
                                                     JOIN PACKHEADER (NOLOCK) ON PACKHEADER.Pickslipno = PACKDETAIL.Pickslipno
                                                     WHERE PACKHEADER.OrderKey = ORD.OrderKey) AS TotalCarton
   FROM PackHeader AS ph WITH(NOLOCK) 
   JOIN PACKDETAIL PAD WITH (NOLOCK) ON PAD.PICKSLIPNO = ph.PICKSLIPNO  
   JOIN Orders ORD WITH (NOLOCK) ON ORD.OrderKey = ph.OrderKey 
   WHERE PAD.PickSlipNo = @c_Pickslipno
   AND PAD.CartonNo BETWEEN @c_FromCartonNo AND @c_ToCartonNo
   GROUP BY PH.PickSlipNo
          , ORD.Loadkey
          , ORD.Consigneekey
          , ORD.C_Company
          , ISNULL(ORD.C_Address1,'') 
          , ISNULL(ORD.C_Address2,'') 
          , ISNULL(ORD.C_Address3,'') 
          , ISNULL(ORD.C_Address4,'')
          , PAD.CartonNo
          , ORD.DeliveryDate
          , ORD.ExternOrderKey
          , ORD.UserDefine09
          , PAD.LabelNo
          , ORD.OrderKey
   
   DECLARE CUR_EDITDATE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT PICKSLIPNO, CARTONNO
   FROM #RESULT
   
   OPEN CUR_EDITDATE
   
   FETCH NEXT FROM CUR_EDITDATE INTO @c_GetPickslipno, @n_CartonNo
   
   WHILE @@FETCH_STATUS <> -1
   BEGIN
        SELECT @d_editdate    = MAX(EDITDATE),
               @n_SumPackQty  = SUM(QTY) 
        FROM PACKDETAIL (NOLOCK)
        WHERE PICKSLIPNO = @c_GetPickslipno 
        AND CARTONNO = @n_CartonNo
   
        UPDATE #RESULT
        SET EditDate = @d_editdate, TotalPcs = @n_SumPackQty
        WHERE PICKSLIPNO = @c_GetPickslipno 
        AND CARTONNO = @n_CartonNo
   
   FETCH NEXT FROM CUR_EDITDATE INTO @c_GetPickslipno, @n_CartonNo
   END
   CLOSE CUR_EDITDATE
   DEALLOCATE CUR_EDITDATE

   SELECT * FROM #RESULT
   ORDER BY CartonNo

   IF OBJECT_ID('tempdb..#RESULT ','u') IS NOT NULL 
      DROP TABLE #RESULT 
END

GO