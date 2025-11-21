SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_nikeph_ConsoDespatchTkt                        */
/* Creation Date: 29-Mar-2019                                           */
/* Copyright: LF                                                        */
/* Written by: WLCHOOI                                                  */
/*                                                                      */
/* Purpose: WMS-8399 - NIKE PH Shipping and Case Label                  */
/*                                                                      */
/* Called By: r_dw_despatch_ticket_nikeph                               */
/*            modified from isp_nikecn_ConsoDespatchTkt7                */
/*                          r_dw_despatch_ticket_nikecn7                */
/* PVCS Version: 2.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 2019-06-26   Shong    1.1  Bug Fixing                                */
/* 2019-10-29   mingle01 1.2  Add trackingno                            */
/* 2020-03-24   WLChooi  1.3  WMS-12359 - Modify logic (WL01)           */
/************************************************************************/
CREATE PROC [dbo].[isp_nikeph_ConsoDespatchTkt]
   --WL01 START
   --@c_pickslipno     NVARCHAR(10),
   --@n_StartCartonNo  INT = 0,
   --@n_EndCartonNo    INT = 0,
   --@c_StartLabelNo   NVARCHAR(20) = '',
   --@c_EndLabelNo     NVARCHAR(20) = ''
   @c_LabelNo        NVARCHAR(50),
   @n_StartCartonNo  INT = 0,
   @n_EndCartonNo    INT = 0
   --WL01 END
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
         , @SQL               NVARCHAR(1000)
         , @nMaxCartonNo      INT
         , @nCartonNo         INT
         , @nSumPackQty       INT
         , @nSumPickQty       INT
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

   --WL01 START
   SET @n_StartCartonNo = ISNULL(@n_StartCartonNo,0)
   SET @n_EndCartonNo   = ISNULL(@n_EndCartonNo,0)
 
   ----Check Pickslipno or ExternOrderKey
   --IF EXISTS (SELECT 1 FROM ORDERS (NOLOCK) WHERE ExternOrderKey = @c_pickslipno)
   --BEGIN
   --	  SELECT @c_pickslipno    = PH.PICKSLIPNO
   --	  FROM PACKHEADER PH (NOLOCK)
   --	  JOIN ORDERS ORD (NOLOCK) ON ORD.ORDERKEY = PH.ORDERKEY
   --	  WHERE ORD.EXTERNORDERKEY = @c_pickslipno
   --	  GROUP BY PH.PICKSLIPNO
        
   --     SET  @c_StartLabelNo = ''
   --     SET  @c_EndLabelNo  = ''
   --END
   
   --SELECT DISTINCT @c_Orderkey = Orderkey 
   --               ,@c_Storerkey= ISNULL(RTRIM(Storerkey),'')   
   --FROM PICKDETAIL (NOLOCK)
   --WHERE Pickslipno = @c_Pickslipno

   --WL01 END

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
       --TrackingNo      NVARCHAR(20) NULL,
       Wavekey         NVARCHAR(10) NULL,  --WL01
       LabelNo         NVARCHAR(20) NULL,  --WL01
       TotalCarton     INT NULL --WL01
   )

   CREATE INDEX IX_RESULT_01 on #RESULT ( LoadKey )
   CREATE INDEX IX_RESULT_02 on #RESULT ( CartonNo )

   INSERT INTO #RESULT
   SELECT PH.Pickslipno AS Pickslipno
         ,ORD.Loadkey AS Loadkey
         ,ISNULL(MAX(ORD.Consigneekey),'') as ConsigneeKey
         ,ISNULL(MAX(ORD.C_Company),'') as C_Company
         ,ISNULL(MAX(ORD.C_Address1),'') as C_Address1
         ,ISNULL(MAX(ORD.C_Address2),'') as C_Address2
         ,ISNULL(MAX(ORD.C_Address3),'') as C_Address3
         ,ISNULL(MAX(ORD.C_Address4),'') as C_Address4
         ,PAD.CartonNo AS CartonNo
         ,0 AS TotalPCS
         ,ORD.DeliveryDate AS CRD
         ,'' AS EditDate
         ,ORD.ExternOrderKey AS Externorderkey
         ,ISNULL(MAX(ORD.C_City),'') AS C_City
         ,ISNULL(MAX(ORD.ExternPOKey),'') AS ExternPOKey
         --,ISNULL(MAX(ORD.TrackingNo),'') AS TrackingNo --mingle01
         ,ORD.UserDefine09   --WL01
         ,PAD.LabelNo   --WL01
         ,(SELECT COUNT(DISTINCT PACKDETAIL.LabelNo) FROM PACKDETAIL (NOLOCK) 
                                                     JOIN PACKHEADER (NOLOCK) ON PACKHEADER.Pickslipno = PACKDETAIL.Pickslipno
                                                     WHERE PACKHEADER.OrderKey = ORD.OrderKey) AS TotalCarton   --WL01
      FROM PackHeader AS ph WITH(NOLOCK) 
      JOIN PACKDETAIL PAD WITH (NOLOCK) ON PAD.PICKSLIPNO = ph.PICKSLIPNO  
      JOIN Orders ORD WITH (NOLOCK) ON ORD.OrderKey = ph.OrderKey 
      --WHERE PH.Pickslipno = @c_pickslipno   --WL01
      WHERE PAD.LabelNo = @c_LabelNo   --WL01
      AND PAD.CartonNo BETWEEN CASE WHEN @n_StartCartonNo = 0 THEN PAD.CartonNo ELSE @n_StartCartonNo END AND
                               CASE WHEN @n_EndCartonNo   = 0 THEN PAD.CartonNo ELSE @n_EndCartonNo END
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
             --, ORD.TrackingNo --mingle01
             ,ORD.UserDefine09
             ,PAD.LabelNo
             ,ORD.OrderKey
   
   --SELECT PD.Pickslipno AS Pickslipno
   --      ,ORD.Loadkey AS Loadkey
   --      ,ISNULL(MAX(ORD.Consigneekey),'') as ConsigneeKey
   --      ,ISNULL(MAX(ORD.C_Company),'') as C_Company
   --      ,ISNULL(MAX(ORD.C_Address1),'') as C_Address1
   --      ,ISNULL(MAX(ORD.C_Address2),'') as C_Address2
   --      ,ISNULL(MAX(ORD.C_Address3),'') as C_Address3
   --      ,ISNULL(MAX(ORD.C_Address4),'') as C_Address4
   --      ,PAD.CartonNo AS CartonNo
   --      ,0 AS TotalPCS
   --      ,ORD.DeliveryDate AS CRD
   --      ,'' AS EditDate
   --      ,ORD.ExternOrderKey AS Externorderkey
   --      ,ISNULL(MAX(ORD.C_City),'') AS C_City
   --      ,ISNULL(MAX(ORD.ExternPOKey),'') AS ExternPOKey
   --      FROM Orders ORD WITH (NOLOCK)
   --       JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey = ORD.OrderKey
   --      JOIN Pickdetail PD WITH (NOLOCK) ON (PD.ORDERKEY = OD.OrderKey AND PD.SKU = OD.SKU AND PD.OrderLineNumber=OD.OrderLineNumber)
   --      JOIN PACKDETAIL PAD WITH (NOLOCK) ON PAD.PICKSLIPNO = PD.PICKSLIPNO
   --      WHERE PAD.Pickslipno = @c_pickslipno
   --      AND PAD.CartonNo BETWEEN CASE WHEN @n_StartCartonNo = 0 THEN 1 ELSE @n_StartCartonNo END AND
   --                                   CASE WHEN @n_EndCartonNo   = 0 THEN 9999 ELSE @n_EndCartonNo END
   --      GROUP BY PD.PickSlipNo
   --               , ORD.Loadkey
   --               , ORD.Consigneekey
   --               , ORD.C_Company
   --               , ISNULL(ORD.C_Address1,'') 
   --               , ISNULL(ORD.C_Address2,'') 
   --               , ISNULL(ORD.C_Address3,'') 
   --               , ISNULL(ORD.C_Address4,'')
   --               , PAD.CartonNo
   --               , ORD.DeliveryDate
   --               , ORD.ExternOrderKey
                  
       DECLARE CUR_EDITDATE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
       SELECT DISTINCT PICKSLIPNO, CARTONNO
       FROM #RESULT

       OPEN CUR_EDITDATE

       FETCH NEXT FROM CUR_EDITDATE INTO @c_GetPickslipno, @nCartonNo

       WHILE @@FETCH_STATUS <> -1
       BEGIN
            SELECT @d_editdate  = MAX(EDITDATE),
                   @nSumPackQty = SUM(QTY) 
            FROM PACKDETAIL (NOLOCK)
            WHERE PICKSLIPNO = @c_GetPickslipno 
            AND CARTONNO = @nCartonNo

            UPDATE #RESULT
            SET EditDate = @d_editdate, TotalPcs = @nSumPackQty
            WHERE PICKSLIPNO = @c_GetPickslipno 
            AND CARTONNO = @nCartonNo

       FETCH NEXT FROM CUR_EDITDATE INTO @c_GetPickslipno, @nCartonNo
       END
       CLOSE CUR_EDITDATE
       DEALLOCATE CUR_EDITDATE
                 

     SELECT * FROM #RESULT
     ORDER BY CartonNo

     IF OBJECT_ID('tempdb..#RESULT ','u') IS NOT NULL 
     DROP TABLE #RESULT 
END

GO