SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store Procedure:  isp_packinglist_detail                             */
/* Creation Date:29-JAN-2018                                            */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/* Purpose: WMS-3705                                                    */
/*                                                                      */
/* Input Parameters: @c_pickslipno                                      */
/*                                                                      */
/* Called By:  dw = r_dw_packing_list_detail                            */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 2018-Mar-05  CSCHONG       WMS-3978-revised field mapping (CS01)     */
/* 2018-MAR-29  CSCHONG       Revised scripts for carton no issue (CS02)*/
/* 2018-Oct-25  CSCHONG       Performance tunning (CS03)                */
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length      */
/* 26-OCT-2022  CSCHONG       WMS-20996 revised field logic (CS04)      */
/************************************************************************/

CREATE PROC [dbo].[isp_packinglist_detail] (
   @c_pickslipno              NVARCHAR( 10),
   @c_RefNo                   NVARCHAR(20) = ''
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @c_Zone               NVARCHAR(30)
           ,@c_storerkey          NVARCHAR(20)
           ,@n_MaxCartonNo        INT
           ,@n_ExcludeCarton      INT
          -- , @c_Zone            NVARCHAR(30)           --(CS02)
           ,@n_cntRefno           INT                    --(CS01)
           ,@c_site               NVARCHAR(30)           --(CS01)
           ,@c_showconsignee      NVARCHAR(1)='N'        --(CS04)
           ,@c_consoord           NVARCHAR(1)='N'        --(CS04)
           ,@c_getordkey          NVARCHAR(20)=''        --(CS04)

   DECLARE @n_NewCartonNo      	INT
         , @n_OriginalCartonNo 	INT

   SELECT @c_storerkey = PH.Storerkey
   FROM PACKHEADER PH (NOLOCK)
   WHERE PH.PickSlipNo=@c_pickslipno

   SET @c_zone = ''

   SELECT @c_zone = C.code2
   FROM CODELKUP C WITH (NOLOCK)
   WHERE C.LISTNAME='REPORTCFG'
   AND C.Storerkey = @c_storerkey
   AND C.Code = 'PackListFilterByRefNo'
   AND C.Long = 'r_dw_packing_list_detail'


      /*CS04 S*/

   SET @c_getordkey=''
   SET @c_consoord='N'

   SELECT @c_getordkey=ph.orderkey
   FROM dbo.PackHeader ph (NOLOCK)
   WHERE ph.Pickslipno = @c_pickslipno

   IF @c_getordkey =''
   BEGIN
     SET @c_consoord='Y'
   END

   SELECT @c_showconsignee =  CASE WHEN ISNULL(CLR.Code,'') <> '' THEN 'Y' ELSE 'N' END      
   FROM CODELKUP CLR WITH (NOLOCK)
   WHERE CLR.LISTNAME='REPORTCFG'
   AND CLR.Storerkey = @c_storerkey
   AND CLR.Code = 'SHOWCONSIGNEE'
   AND CLR.Long = 'r_dw_packing_list_detail'
   AND ISNULL(CLR.Short,'') <> 'N'  


   CREATE TABLE #TMP_PACKDETORD (
        RowRef            INT NOT NULL IDENTITY(1,1) PRIMARY KEY
      , Orderkey          NVARCHAR(10)   NULL
      , ExternOrderkey    NVARCHAR(50)   NULL  
      , ConsigneeKey      NVARCHAR(15)   NULL
      , C_Contact1        NVARCHAR(30)   NULL
      , C_Address1        NVARCHAR(45)   NULL
      , C_Address2        NVARCHAR(45)   NULL
      , C_Address3        NVARCHAR(45)   NULL
      , C_Address4        NVARCHAR(45)   NULL
      , C_Phone1          NVARCHAR(18)   NULL
      , DeliveryDate      DATETIME       NULL
      , Loadkey           NVARCHAR(20)   NULL
      , BuyerPO           NVARCHAR(20)   NULL
      , C_Company         NVARCHAR(45)   NULL
      , B_Company         NVARCHAR(45)   NULL
      , showconsignee     NVARCHAR(30)   NULL  
      , RSCStorer         NVARCHAR(1)    DEFAULT 'N'
      , Storerkey         NVARCHAR(20)   NULL
      , SKU               NVARCHAR(20)   NULL
      , CartonNo          INT            NULL
      , PickSlipNo        NVARCHAR(10)   NULL
      , PackQty           INT            NULL
      , LabelNo           NVARCHAR(20)   NULL
      , Refno             NVARCHAR(20)   NULL
      , Refno2            NVARCHAR(30)   NULL
      , LabelLine         NVARCHAR(5)    NULL
                               )

  IF @c_consoord='N'
  BEGIN
       INSERT INTO #TMP_PACKDETORD
       (
           Orderkey,
           ExternOrderkey,
           ConsigneeKey,
           C_Contact1,
           C_Address1,
           C_Address2,
           C_Address3,
           C_Address4,
           C_Phone1,
           DeliveryDate,
           Loadkey,
           BuyerPO,
           C_Company,
           B_Company,
           showconsignee,
           RSCStorer,Storerkey,
           sku,Cartonno,PickSlipNo,PackQty,LabelNo,Refno,Refno2,LabelLine
       )
       SELECT  ORDERS.OrderKey,
         ORDERS.ExternOrderKey,
         ORDERS.ConsigneeKey,     
         ORDERS.C_contact1,
         CASE WHEN ISNULL(ST.storerkey,'') <> ''  THEN ST.Address2 ELSE CASE WHEN  @c_showconsignee = 'Y' THEN ORDERS.C_Address2 ELSE ORDERS.C_Address1 END END , 
         CASE WHEN ISNULL(ST.storerkey,'') <> ''  THEN ST.Address1 ELSE CASE WHEN  @c_showconsignee = 'Y' THEN ORDERS.C_Address1 ELSE ORDERS.C_Address2 END END,   
         CASE WHEN ISNULL(ST.storerkey,'') <> ''  THEN ST.Address3 ELSE CASE WHEN  @c_showconsignee= 'Y' THEN ORDERS.C_Address3 ELSE ORDERS.C_Address3 END END,   
         ORDERS.C_Address4,
         ORDERS.C_Phone1,
         ORDERS.DeliveryDate,
         ORDERS.loadkey,
         ORDERS.BuyerPO ,
         CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN ST.company ELSE ORDERS.C_Company END, 
         orders.B_company ,
         @c_showconsignee AS showconsignee ,
         CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN 'Y' ELSE 'N' END,
         orders.storerkey,
         OD.Sku,PackDetail.cartonno,packheader.pickslipno,packdetail.qty,
         packdetail.labelno,packdetail.refno,packdetail.refno2,'' AS labeline
         FROM ORDERS (NOLOCK)
         LEFT JOIN ORDERDETAIL OD (NOLOCK) ON ORDERS.OrderKey=OD.OrderKey
         LEFT JOIN PICKDETAIL  (NOLOCK) ON OD.OrderKey=PICKDETAIL.OrderKey AND PICKDETAIL.Sku=OD.SKU AND OD.OrderLineNumber = PICKDETAIL.OrderLineNumber
         LEFT JOIN  PackDetail   (NOLOCK) ON PackDetail.LabelNo=PICKDETAIL.DropID AND OD.Sku=PackDetail.SKU
         JOIN dbo.PackHeader (NOLOCK) ON Packheader.OrderKey=ORDERS.ORderkey
         --JOIN PackHeader (NOLOCK) ON Packheader.Orderkey = Orders.Orderkey         
         --                     AND Packheader.Loadkey = Orders.Loadkey
         --                     AND Packheader.Consigneekey = Orders.Consigneekey
   LEFT JOIN STORER ST (NOLOCK) ON ST.StorerKey = orders.B_Company AND ST.type='4'AND ST.ConsigneeFor='NIKECN' AND ST.Notes1='RSC' 
   WHERE ( RTRIM(PackHeader.OrderKey) IS NOT NULL AND RTRIM(PackHeader.OrderKey) <> '') AND
          Packheader.Pickslipno = @c_pickslipno AND packdetail.refno= CASE WHEN @c_RefNo <> '' THEN @c_RefNo ELSE packdetail.refno END
    GROUP BY Packheader.Loadkey,
            Orders.Consigneekey,
            Orders.Orderkey,
            Orders.ExternOrderkey,
            Orders.BuyerPO,
            ORDERS.C_Address1 ,
            ORDERS.C_Address2 ,
            ORDERS.C_Address3 ,   
            Orders.C_Address4,
            Orders.C_contact1,
            Orders.C_Phone1,
            Orders.DeliveryDate,
            Orders.loadkey, 
            CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN ST.company ELSE ORDERS.C_Company END        
            , ISNULL(ST.storerkey,'')                                       
            ,orders.B_company                                                
            ,ST.Address2
            ,ST.Address1
            ,ST.Address3 
            ,orders.storerkey  
            , OD.Sku,PackDetail.cartonno,packheader.pickslipno,packdetail.qty,
              packdetail.labelno,packdetail.refno,packdetail.refno2

   END
   ELSE IF @c_consoord='Y'
   BEGIN     
    -- UNION
   
           IF @c_showconsignee ='N'
           BEGIN

          INSERT INTO #TMP_PACKDETORD
       (
           Orderkey,
           ExternOrderkey,
           ConsigneeKey,
           C_Contact1,
           C_Address1,
           C_Address2,
           C_Address3,
           C_Address4,
           C_Phone1,
           DeliveryDate,
           Loadkey,
           BuyerPO,
           C_Company,
           B_Company,
           showconsignee,
           RSCStorer,Storerkey,
           sku,Cartonno,PickSlipNo,PackQty,LabelNo,Refno,Refno2,LabelLine
       )
            SELECT '' AS OrderKey,
               '' AS ExternOrderKey,
               '' AS ConsigneeKey,
               MAX(ORDERS.C_contact1) AS C_contact1,
               CASE WHEN ISNULL(ST.storerkey,'') <> ''  THEN MAX(ST.Address2) 
                                                        ELSE CASE WHEN  @c_showconsignee = 'Y' THEN MAX(ORDERS.C_Address2) ELSE MAX(ORDERS.C_Address1) END END , 
               CASE WHEN ISNULL(ST.storerkey,'') <> ''  THEN MAX(ST.Address1) 
                                                        ELSE CASE WHEN  @c_showconsignee = 'Y' THEN MAX(ORDERS.C_Address1) ELSE MAX(ORDERS.C_Address2) END END , 
               CASE WHEN ISNULL(ST.storerkey,'') <> ''  THEN MAX(ST.Address3) 
                                                        ELSE CASE WHEN  @c_showconsignee = 'Y' THEN MAX(ORDERS.C_Address3) ELSE MAX(ORDERS.C_Address3) END END , 
               MAX(ORDERS.C_Address4) AS C_Address4,
               MAX(ORDERS.C_Phone1) AS C_Phone1,
               MAX(ORDERS.DeliveryDate) AS DeliveryDate,
               orders.LoadKey,
               '' AS BuyerPO,
               CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN MAX(ST.company) ELSE MAX(Orders.C_Company) END AS C_Company,
               '' AS b_company,
               @c_showconsignee AS showconsignee ,
               CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN 'Y' ELSE 'N' END ,
              MAX(orders.storerkey) ,
               OD.Sku,PackDetail.cartonno,packheader.pickslipno,
               SUM(Packdetail.Qty) AS PackQty,
              packdetail.labelno,packdetail.refno,packdetail.refno2,packdetail.labelline
         --FROM PackDetail (NOLOCK)
         --JOIN PackHeader (NOLOCK) ON ( PackDetail.PickSlipNo = PackHeader.PickSlipNo )
         --JOIN  ORDERS (NOLOCK) ON Orders.loadkey = Packheader.loadkey      
         FROM ORDERS (NOLOCK)
         LEFT JOIN ORDERDETAIL OD (NOLOCK) ON ORDERS.OrderKey=OD.OrderKey
         LEFT JOIN PICKDETAIL  (NOLOCK) ON OD.OrderKey=PICKDETAIL.OrderKey AND PICKDETAIL.Sku=OD.SKU  AND OD.OrderLineNumber = PICKDETAIL.OrderLineNumber
         LEFT JOIN  PackDetail   (NOLOCK) ON PackDetail.LabelNo=PICKDETAIL.DropID AND OD.Sku=PackDetail.SKU
         JOIN dbo.PackHeader (NOLOCK) ON Packheader.loadkey=ORDERS.loadkey                      
         LEFT JOIN STORER ST (NOLOCK) ON ST.StorerKey = orders.B_Company AND ST.type='4'AND ST.ConsigneeFor='NIKECN' AND ST.Notes1='RSC' 
         WHERE ( RTRIM(PackHeader.OrderKey) IS NULL OR RTRIM(PackHeader.OrderKey) = '') AND
               ( Packheader.Pickslipno = @c_pickslipno ) 
               AND packdetail.refno= CASE WHEN @c_RefNo <> '' THEN @c_RefNo ELSE packdetail.refno END
         GROUP BY orders.Loadkey,
                ISNULL(ST.storerkey,'') ,OD.Sku,PackDetail.cartonno,packheader.pickslipno,
             --  Packdetail.Qty,
              packdetail.labelno,packdetail.refno,packdetail.refno2,packdetail.labelline
         END
         ELSE
         BEGIN
         INSERT INTO #TMP_PACKDETORD
       (
           Orderkey,
           ExternOrderkey,
           ConsigneeKey,
           C_Contact1,
           C_Address1,
           C_Address2,
           C_Address3,
           C_Address4,
           C_Phone1,
           DeliveryDate,
           Loadkey,
           BuyerPO,
           C_Company,
           B_Company,
           showconsignee,
           RSCStorer,Storerkey,
           sku,Cartonno,PickSlipNo,PackQty,LabelNo,Refno,Refno2,LabelLine
       )
              SELECT '' AS OrderKey,
               '' AS ExternOrderKey,
               (ORDERS.consigneekey) AS ConsigneeKey,
               MAX(ORDERS.C_contact1) AS C_contact1,
               CASE WHEN ISNULL(ST.storerkey,'') <> ''  THEN MAX(ST.Address2) 
                                                        ELSE CASE WHEN  @c_showconsignee = 'Y' THEN MAX(ORDERS.C_Address2) ELSE MAX(ORDERS.C_Address1) END END , 
               CASE WHEN ISNULL(ST.storerkey,'') <> ''  THEN MAX(ST.Address1) 
                                                        ELSE CASE WHEN  @c_showconsignee = 'Y' THEN MAX(ORDERS.C_Address1) ELSE MAX(ORDERS.C_Address2) END END , 
               CASE WHEN ISNULL(ST.storerkey,'') <> ''  THEN MAX(ST.Address3) 
                                                        ELSE CASE WHEN  @c_showconsignee = 'Y' THEN MAX(ORDERS.C_Address3) ELSE MAX(ORDERS.C_Address3) END END , 
               MAX(ORDERS.C_Address4) AS C_Address4,
               MAX(ORDERS.C_Phone1) AS C_Phone1,
               MAX(ORDERS.DeliveryDate) AS DeliveryDate,
               orders.LoadKey,
               '' AS BuyerPO,
               CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN MAX(ST.company) ELSE MAX(Orders.C_Company) END AS C_Company,
               '' AS b_company,
               @c_showconsignee AS showconsignee ,
               CASE WHEN ISNULL(ST.storerkey,'') <> '' THEN 'Y' ELSE 'N' END ,
              MAX(orders.storerkey) ,OD.Sku,PackDetail.cartonno,packheader.pickslipno,
              SUM(pickdetail.qty)  AS PackQty,
              packdetail.labelno,packdetail.refno,packdetail.refno2,packdetail.labelline
         FROM ORDERS (NOLOCK)
         LEFT JOIN ORDERDETAIL OD (NOLOCK) ON ORDERS.OrderKey=OD.OrderKey
         LEFT JOIN PICKDETAIL  (NOLOCK) ON OD.OrderKey=PICKDETAIL.OrderKey AND PICKDETAIL.Sku=OD.SKU  AND OD.OrderLineNumber = PICKDETAIL.OrderLineNumber
         LEFT JOIN  PackDetail   (NOLOCK) ON PackDetail.LabelNo=PICKDETAIL.DropID AND OD.Sku=PackDetail.SKU
         JOIN dbo.PackHeader (NOLOCK) ON Packheader.loadkey=ORDERS.loadkey                              
         LEFT JOIN STORER ST (NOLOCK) ON ST.StorerKey = orders.B_Company AND ST.type='4'AND ST.ConsigneeFor='NIKECN' AND ST.Notes1='RSC' 
         WHERE ( RTRIM(PackHeader.OrderKey) IS NULL OR RTRIM(PackHeader.OrderKey) = '') AND
               ( Packheader.Pickslipno = @c_pickslipno )
          AND packdetail.refno= CASE WHEN @c_RefNo <> '' THEN @c_RefNo ELSE packdetail.refno END
         GROUP BY orders.Loadkey,
                ISNULL(ST.storerkey,'') ,(ORDERS.consigneekey) ,OD.Sku,PackDetail.cartonno,packheader.pickslipno,
             -- pickdetail.qty,
              packdetail.labelno,packdetail.refno,packdetail.refno2,packdetail.labelline

         END
 END                                                                                         
--    SELECT * FROM #TMP_PACKDETORD
--   SELECT '' AS OrderKey,
--         '' AS ExternOrderKey,
--         CASE WHEN ISNULL(TORD.ConsigneeKey,'') <> '' THEN ISNULL(TORD.ConsigneeKey,'')  ELSE '' END AS ConsigneeKey,
--         MAX(TORD.C_contact1) AS C_contact1,     --CS04 S
--         MAX(TORD.C_Address1) AS C_Address1,     
--         MAX(TORD.C_Address2) AS C_Address2,
--         MAX(TORD.C_Address3) AS C_Address3,
--         MAX(TORD.C_Address4) AS C_Address4,
--         MAX(TORD.C_Phone1) AS C_Phone1,
--         MAX(TORD.DeliveryDate) AS DeliveryDate,   --CS04 E
--         TORD.SKU,
--         TORD.CartonNo,
--         TORD.PickSlipNo,
--         TORD.LoadKey,
--         --CASE WHEN ISNULL(TORD.showconsignee,'') = 'Y' THEN pid.qty ELSE Packdetail.Qty END AS PackQty,   --CS04
--         TORD.PackQty AS packqty,  
--         '' AS BuyerPO,
--         MAX(TORD.C_Company) AS C_Company,    --CS04
--         CONVERT(DECIMAL(10,5), ISNULL(PACKINFO.Weight,0)) AS PWGT,
--         CONVERT(DECIMAL(10,5), ISNULL(PACKINFO.[Cube],0)) AS PCube,
--         CONVERT(DECIMAL(10,5), ISNULL(PACKINFOSUM.TotalWeight,0)) AS PISTTLWGT,
--         CONVERT(DECIMAL(10,5), ISNULL(PACKINFOSUM.TotalCube,0)) AS PISTTTLCUBE,
--         TORD.LabelLine,
--         SKU.PackQtyIndicator,
--         PACK.PackUOM3,
--         TORD.LabelNo,
--         CASE WHEN ISNULL(CLR.Code,'') = '' THEN 'N' ELSE 'Y' END AS showfullsku,
--         CASE WHEN ISNULL(CLR1.Code,'') = '' THEN '' ELSE ('2' + RIGHT(TORD.orderkey,9)) END AS LBIShipNo,
--         CASE WHEN ISNULL(CLR1.Code,'') = '' THEN 'N' ELSE 'Y' END AS showlbiship
--         ,'' AS [SITE]                                     --CS02
--         ,CASE WHEN @c_zone <> '' THEN TORD.RefNo ELSE '' END            --CS01
--         ,CASE WHEN @c_zone <> '' THEN TORD.RefNo2 ELSE '' END            --CS01
--         ,TORD.showconsignee AS showconsignee   --CS04
--   --FROM  #TMP_PACKDETORD TORD (NOLOCK)
--   --FROM PackDetail (NOLOCK)
--   --FROM PackHeader (NOLOCK)
--   --JOIN PackDetail (NOLOCK) ON ( PackDetail.PickSlipNo = PackHeader.PickSlipNo )
--   --JOIN LoadplanDetail (NOLOCK) ON ( Packheader.Loadkey = LoadplanDetail.LoadKey )       --(CS03)
--   --JOIN ORDERS (NOLOCK) ON ( Orders.Orderkey = LoadplanDetail.OrderKey )
--   --JOIN  ORDERS (NOLOCK) ON Orders.loadkey = Packheader.loadkey                            --(CS03)
--    FROM #TMP_PACKDETORD TORD (NOLOCK) --ON TORD.loadkey = Packheader.loadkey  AND TORD.CartonNo = PackDetail.CartonNo 
--  --  AND TORD.SKU=packdetail.sku AND TORD.PickSlipNo = PackDetail.PickSlipNo              --(CS04)
--   JOIN SKU (NOLOCK) ON ( TORD.Sku = SKU.Sku AND TORD.StorerKey = SKU.StorerKey )
--  -- JOIN dbo.ORDERDETAIL OD (NOLOCK) ON OD.OrderKey=TORD.Orderkey
--   JOIN PACK (NOLOCK) ON ( SKU.PackKey = PACK.PackKey )
--   LEFT OUTER JOIN PACKINFO (NOLOCK) ON ( TORD.PickSlipNo = PACKINFO.PickSlipNo
--                                      AND TORD.CartonNo = PACKINFO.CartonNo )
--   LEFT OUTER JOIN ( SELECT PickSlipNo,CartonNo, SUM(Weight) AS TotalWeight, SUM(Cube) AS TotalCube
--                     FROM PACKINFO (NOLOCK) GROUP BY PickSlipNo,CartonNo ) AS PACKINFOSUM
--                ON ( PACKINFO.PickSlipNo = PACKINFOSUM.PickSlipNo AND PACKINFO.CartonNo = PACKINFOSUM.CartonNo)
--   LEFT OUTER JOIN Codelkup CLR (NOLOCK) ON (TORD.Storerkey = CLR.Storerkey AND CLR.Code = 'SHOWFULLSKU'
--                                         AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_packing_list_detail' AND ISNULL(CLR.Short,'') <> 'N')
--   LEFT OUTER JOIN Codelkup CLR1 (NOLOCK) ON (TORD.Storerkey = CLR1.Storerkey AND CLR1.Code = 'SHOWLBISHIP'
--                                          AND CLR1.Listname = 'REPORTCFG' AND CLR1.Long = 'r_dw_packing_list_detail' AND ISNULL(CLR1.Short,'') <> 'N')
------CS04 S
--   -- LEFT JOIN dbo.PICKDETAIL PID WITH (NOLOCK) ON PID.DropID=packdetail.labelno AND PID.sku=packdetail.sku AND PID.Status='5'
--    --CROSS APPLY( SELECT dropid,sku,(qty) AS qty FROM PICKDETAIL WITH (NOLOCK) WHERE Status='5' AND DropID=TORD.labelno AND sku=TORD.sku ) AS pid
----   LEFT JOIN STORER ST (NOLOCK) ON ST.StorerKey = orders.B_Company AND ST.type='4'AND ST.ConsigneeFor='NIKECN' AND ST.Notes1='RSC' 
----   LEFT OUTER JOIN Codelkup CLR2 (NOLOCK) ON (ORDERS.Storerkey = CLR2.Storerkey AND CLR2.Code = 'SHOWCONSIGNEE'
----                                          AND CLR2.Listname = 'REPORTCFG' AND CLR2.Long = 'r_dw_packing_list_detail' AND ISNULL(CLR2.Short,'') <> 'N')
------CS04 E
--   WHERE ( RTRIM(TORD.OrderKey) IS NULL OR RTRIM(TORD.OrderKey) = '') AND
--         ( TORD.Pickslipno = @c_pickslipno )
--   GROUP BY TORD.Loadkey,
--            TORD.Pickslipno,
--            TORD.CartonNo,
--            TORD.Sku,
--           -- Packdetail.Qty,
--            TORD.PackQty,--CASE WHEN ISNULL(TORD.showconsignee,'') = 'Y' THEN pid.qty ELSE Packdetail.Qty END,  --CS04
--            CONVERT(DECIMAL(10,5), ISNULL(PACKINFO.Weight,0)),
--            CONVERT(DECIMAL(10,5), ISNULL(PACKINFO.[Cube],0)),
--            CONVERT(DECIMAL(10,5), ISNULL(PACKINFOSUM.TotalWeight,0)),
--            CONVERT(DECIMAL(10,5), ISNULL(PACKINFOSUM.TotalCube,0)),
--            TORD.LabelLine,
--            SKU.PackQtyIndicator,
--            PACK.PackUOM3,
--            TORD.LabelNo,
--            CASE WHEN ISNULL(CLR.Code,'') = '' THEN 'N' ELSE 'Y' END,
--            CASE WHEN ISNULL(CLR1.Code,'') = '' THEN '' ELSE ('2' + RIGHT(TORD.orderkey,9)) END,    --CS04
--            CASE WHEN ISNULL(CLR1.Code,'') = '' THEN 'N' ELSE 'Y' END
--           ,CASE WHEN @c_zone <> '' THEN TORD.RefNo ELSE '' END            --CS01
--           ,CASE WHEN @c_zone <> '' THEN TORD.RefNo2 ELSE '' END            --CS01
--           ,TORD.showconsignee                                                    --CS04
--           ,TORD.RSCStorer                                                       --CS04
--           ,ISNULL(TORD.ConsigneeKey,'')                                               --CS04
--   ORDER BY TORD.CartonNo

      /*CS04 E*/

   /*CS01 Start*/
   CREATE TABLE #TMP_PACKDET
   (    RowRef            INT NOT NULL IDENTITY(1,1) PRIMARY KEY
      , Orderkey          NVARCHAR(10)   NULL
      , ExternOrderkey    NVARCHAR(50)   NULL  --tlting_ext
      , ConsigneeKey      NVARCHAR(45)   NULL  --CS04
      , C_Contact1        NVARCHAR(30)   NULL
      , C_Address1        NVARCHAR(45)   NULL
      , C_Address2        NVARCHAR(45)   NULL
      , C_Address3        NVARCHAR(45)   NULL
      , C_Address4        NVARCHAR(45)   NULL
      , C_Phone1          NVARCHAR(18)   NULL
      , DeliveryDate      DATETIME       NULL
      , SKU               NVARCHAR(20)   NULL
      , CartonNo          INT            NULL
      , PickSlipNo        NVARCHAR(10)   NULL
      , LoadKey           NVARCHAR(10)   NULL
      , PackQty           INT            NULL
      , BuyerPO           NVARCHAR(20)   NULL
      , C_Company         NVARCHAR(45)   NULL
      , PWGT              DECIMAL(10,5)  NULL
      , PCube             DECIMAL(10,5)  NULL
      , PISTTLWGT         DECIMAL(10,5)  NULL
      , PISTTTLCUBE       DECIMAL(10,5)  NULL
      , LabelLine         NVARCHAR(5)    NULL
      , PackQtyIndicator  INT            NULL
      , PackUOM3          NVARCHAR(10)   NULL
      , LabelNo           NVARCHAR(20)   NULL
      , showfullsku       NVARCHAR(30)   NULL
      , LBIShipNo         NVARCHAR(30)   NULL
      , showlbiship       NVARCHAR(30)   NULL
      , LSite             NVARCHAR(50)   NULL
      , Refno             NVARCHAR(20)   NULL
      , Refno2            NVARCHAR(30)   NULL
      , showconsignee     NVARCHAR(30)   NULL    --CS04
   )

   INSERT INTO #TMP_PACKDET
   (    Orderkey
      , ExternOrderkey
      , ConsigneeKey
      , C_Contact1
      , C_Address1
      , C_Address2
      , C_Address3
      , C_Address4
      , C_Phone1
      , DeliveryDate
      , SKU
      , CartonNo
      , PickSlipNo
      , LoadKey
      , PackQty
      , BuyerPO
      , C_Company
      , PWGT
      , PCube
      , PISTTLWGT
      , PISTTTLCUBE
      , LabelLine
      , PackQtyIndicator
      , PackUOM3
      , LabelNo
      , showfullsku
      , LBIShipNo
      , showlbiship
      , Lsite
      , Refno
      , Refno2
      , showconsignee       --CS04
   )

   SELECT TORD.OrderKey,       --CS04 S
         TORD.ExternOrderKey,
         CASE WHEN TORD.RSCStorer ='Y' THEN TORD.B_company ELSE TORD.ConsigneeKey END,      
         TORD.C_contact1,
         TORD.C_Address1 ,  
         TORD.C_Address2 ,  
         TORD.C_Address3 , 
         TORD.C_Address4,
         TORD.C_Phone1,
         TORD.DeliveryDate,   --CS04 E
         TORD.SKU,
         TORD.CartonNo,
         TORD.PickSlipNo,
         TORD.LoadKey,
         (TORD.PackQty) AS PackQty ,
         TORD.BuyerPO ,                               --CS04
         TORD.C_Company ,    
         CONVERT(DECIMAL(10,5), ISNULL(PACKINFO.Weight,0)) AS PWGT,
         CONVERT(DECIMAL(10,5), ISNULL(PACKINFO.[Cube],0)) AS PCube,
         CONVERT(DECIMAL(10,5), ISNULL(PACKINFOSUM.TotalWeight,0)) AS PISTTLWGT,
         CONVERT(DECIMAL(10,5), ISNULL(PACKINFOSUM.TotalCube,0)) AS PISTTTLCUBE,
         '' AS LabelLine,
         SKU.PackQtyIndicator,
         PACK.PackUOM3,
         TORD.LabelNo,
         CASE WHEN ISNULL(CLR.Code,'') = '' THEN 'N' ELSE 'Y' END AS showfullsku,
         CASE WHEN ISNULL(CLR1.Code,'') = '' THEN '' ELSE ('2' + RIGHT(TORD.orderkey,9)) END AS LBIShipNo,     --CS04
         CASE WHEN ISNULL(CLR1.Code,'') = '' THEN 'N' ELSE 'Y' END AS showlbiship
         ,'' AS [SITE]                                                         --CS02
         ,CASE WHEN @c_zone <> '' THEN TORD.RefNo ELSE '' END            --CS01
         ,CASE WHEN @c_zone <> '' THEN TORD.RefNo2 ELSE '' END            --CS01
         ,TORD.showconsignee  --CS04 
   FROM #TMP_PACKDETORD TORD (NOLOCK)
   LEFT JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey = TORD.Orderkey     --CS03
   --JOIN PackHeader (NOLOCK) ON Packheader.Orderkey = TORD.Orderkey           --CS03
   --                           AND Packheader.Loadkey = TORD.Loadkey
   --                           AND Packheader.Consigneekey = TORD.Consigneekey
   --JOIN PackDetail (NOLOCK) ON ( PackDetail.PickSlipNo = PackHeader.PickSlipNo )        --CS03
  --LEFT JOIN PICKDETAIL  (NOLOCK) PID ON OD.OrderKey=PID.OrderKey AND PID.Sku=OD.SKU
  --LEFT JOIN  PackDetail  (NOLOCK) ON PackDetail.LabelNo=PID.DropID AND OD.Sku=PackDetail.SKU                  
  -- LEFT JOIN Packheader (NOLOCK) ON PackHeader.PickSlipNo = PackDetail.PickSlipNo
   JOIN SKU (NOLOCK) ON ( TORD.Sku = SKU.Sku AND TORD.StorerKey = SKU.StorerKey )
   JOIN PACK (NOLOCK) ON ( SKU.PackKey = PACK.PackKey )
   LEFT OUTER JOIN PACKINFO (NOLOCK) ON ( TORD.PickSlipNo = PACKINFO.PickSlipNo
                                      AND TORD.CartonNo = PACKINFO.CartonNo )
   LEFT OUTER JOIN ( SELECT PickSlipNo, SUM(Weight) AS TotalWeight, SUM(Cube) AS TotalCube
                     FROM PACKINFO (NOLOCK) GROUP BY PickSlipNo ) AS PACKINFOSUM
                ON ( PACKINFO.PickSlipNo = PACKINFOSUM.PickSlipNo )
   LEFT OUTER JOIN Codelkup CLR (NOLOCK) ON (TORD.Storerkey = CLR.Storerkey AND CLR.Code = 'SHOWFULLSKU'
               AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_packing_list_detail' AND ISNULL(CLR.Short,'') <> 'N')
   LEFT OUTER JOIN Codelkup CLR1 (NOLOCK) ON (TORD.Storerkey = CLR1.Storerkey AND CLR1.Code = 'SHOWLBISHIP'
                                          AND CLR1.Listname = 'REPORTCFG' AND CLR1.Long = 'r_dw_packing_list_detail' AND ISNULL(CLR1.Short,'') <> 'N')
----CS04 S
--   LEFT JOIN STORER ST (NOLOCK) ON ST.StorerKey = orders.B_Company AND ST.type='4'AND ST.ConsigneeFor='NIKECN' AND ST.Notes1='RSC' 
--   LEFT OUTER JOIN Codelkup CLR2 (NOLOCK) ON (ORDERS.Storerkey = CLR2.Storerkey AND CLR2.Code = 'SHOWCONSIGNEE'
--                                          AND CLR2.Listname = 'REPORTCFG' AND CLR2.Long = 'r_dw_packing_list_detail' AND ISNULL(CLR2.Short,'') <> 'N')
----CS04 E
   WHERE ( RTRIM(TORD.OrderKey) IS NOT NULL AND RTRIM(TORD.OrderKey) <> '') AND
          TORD.Pickslipno = @c_pickslipno
   GROUP BY TORD.Loadkey,
            TORD.Consigneekey,
            TORD.Orderkey,
            TORD.ExternOrderkey,
            TORD.BuyerPO,
            TORD.Pickslipno,
            TORD.CartonNo,
            TORD.Sku,
            TORD.C_Address1,                                   --CS04 S
            TORD.C_Address2,
            TORD.C_Address3,
            TORD.C_Address4,
            TORD.C_contact1,
            TORD.C_Phone1,
            TORD.DeliveryDate,
            TORD.C_Company ,           --Cs04 E
            CONVERT(DECIMAL(10,5), ISNULL(PACKINFO.Weight,0)),
            CONVERT(DECIMAL(10,5), ISNULL(PACKINFO.[Cube],0)),
            CONVERT(DECIMAL(10,5), ISNULL(PACKINFOSUM.TotalWeight,0)),
            CONVERT(DECIMAL(10,5), ISNULL(PACKINFOSUM.TotalCube,0)),
            SKU.PackQtyIndicator,
            PACK.PackUOM3,
            TORD.LabelNo,
            CASE WHEN ISNULL(CLR.Code,'') = '' THEN 'N' ELSE 'Y' END,
            CASE WHEN ISNULL(CLR1.Code,'') = '' THEN '' ELSE ('2' + RIGHT(TORD.orderkey,9)) END,    --CS04
            CASE WHEN ISNULL(CLR1.Code,'') = '' THEN 'N' ELSE 'Y' END
             ,CASE WHEN @c_zone <> '' THEN TORD.RefNo ELSE '' END            --CS01
            ,CASE WHEN @c_zone <> '' THEN TORD.RefNo2 ELSE '' END            --CS01
         --   ,CASE WHEN ISNULL(CLR2.Code,'') = '' THEN 'N' ELSE 'Y' END             --CS04 S
            , TORD.RSCStorer                                                       --CS04
            ,TORD.B_company                                                        --CS04 
            ,TORD.showconsignee                                                    --CS04 
            ,(TORD.PackQty) 
   UNION ALL
   SELECT '' AS OrderKey,
         '' AS ExternOrderKey,
         CASE WHEN ISNULL(TORD.ConsigneeKey,'') <> '' THEN ISNULL(TORD.ConsigneeKey,'')  ELSE '' END AS ConsigneeKey,
         MAX(TORD.C_contact1) AS C_contact1,     --CS04 S
         MAX(TORD.C_Address1) AS C_Address1,     
         MAX(TORD.C_Address2) AS C_Address2,
         MAX(TORD.C_Address3) AS C_Address3,
         MAX(TORD.C_Address4) AS C_Address4,
         MAX(TORD.C_Phone1) AS C_Phone1,
         MAX(TORD.DeliveryDate) AS DeliveryDate,   --CS04 E
         TORD.SKU,
         TORD.CartonNo,
         TORD.PickSlipNo,
         TORD.LoadKey,
         --CASE WHEN ISNULL(TORD.showconsignee,'') = 'Y' THEN pid.qty ELSE Packdetail.Qty END AS PackQty,   --CS04
         TORD.PackQty AS packqty,  
         '' AS BuyerPO,
         MAX(TORD.C_Company) AS C_Company,    --CS04
         CONVERT(DECIMAL(10,5), ISNULL(PACKINFO.Weight,0)) AS PWGT,
         CONVERT(DECIMAL(10,5), ISNULL(PACKINFO.[Cube],0)) AS PCube,
         CONVERT(DECIMAL(10,5), ISNULL(PACKINFOSUM.TotalWeight,0)) AS PISTTLWGT,
         CONVERT(DECIMAL(10,5), ISNULL(PACKINFOSUM.TotalCube,0)) AS PISTTTLCUBE,
         TORD.LabelLine,
         SKU.PackQtyIndicator,
         PACK.PackUOM3,
         TORD.LabelNo,
         CASE WHEN ISNULL(CLR.Code,'') = '' THEN 'N' ELSE 'Y' END AS showfullsku,
         CASE WHEN ISNULL(CLR1.Code,'') = '' THEN '' ELSE ('2' + RIGHT(TORD.orderkey,9)) END AS LBIShipNo,
         CASE WHEN ISNULL(CLR1.Code,'') = '' THEN 'N' ELSE 'Y' END AS showlbiship
         ,'' AS [SITE]                                     --CS02
         ,CASE WHEN @c_zone <> '' THEN TORD.RefNo ELSE '' END            --CS01
         ,CASE WHEN @c_zone <> '' THEN TORD.RefNo2 ELSE '' END            --CS01
         ,TORD.showconsignee AS showconsignee   --CS04
   --FROM  #TMP_PACKDETORD TORD (NOLOCK)
   --FROM PackDetail (NOLOCK)
   --FROM PackHeader (NOLOCK)
   --JOIN PackDetail (NOLOCK) ON ( PackDetail.PickSlipNo = PackHeader.PickSlipNo )
   --JOIN LoadplanDetail (NOLOCK) ON ( Packheader.Loadkey = LoadplanDetail.LoadKey )       --(CS03)
   --JOIN ORDERS (NOLOCK) ON ( Orders.Orderkey = LoadplanDetail.OrderKey )
   --JOIN  ORDERS (NOLOCK) ON Orders.loadkey = Packheader.loadkey                            --(CS03)
    --  LEFT JOIN #TMP_PACKDETORD TORD (NOLOCK) ON TORD.loadkey = Packheader.loadkey  AND TORD.CartonNo = PackDetail.CartonNo 
    --AND TORD.SKU=packdetail.sku AND TORD.PickSlipNo = PackDetail.PickSlipNo              --(CS04)
    FROM #TMP_PACKDETORD TORD (NOLOCK)
   JOIN SKU (NOLOCK) ON ( TORD.Sku = SKU.Sku AND TORD.StorerKey = SKU.StorerKey )
  -- JOIN dbo.ORDERDETAIL OD (NOLOCK) ON OD.OrderKey=TORD.Orderkey
   JOIN PACK (NOLOCK) ON ( SKU.PackKey = PACK.PackKey )
   LEFT OUTER JOIN PACKINFO (NOLOCK) ON ( TORD.PickSlipNo = PACKINFO.PickSlipNo
                                      AND TORD.CartonNo = PACKINFO.CartonNo )
   LEFT OUTER JOIN ( SELECT PickSlipNo, SUM(Weight) AS TotalWeight, SUM(Cube) AS TotalCube
                     FROM PACKINFO (NOLOCK) GROUP BY PickSlipNo ) AS PACKINFOSUM
                ON ( PACKINFO.PickSlipNo = PACKINFOSUM.PickSlipNo )
   LEFT OUTER JOIN Codelkup CLR (NOLOCK) ON (TORD.Storerkey = CLR.Storerkey AND CLR.Code = 'SHOWFULLSKU'
                                         AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_packing_list_detail' AND ISNULL(CLR.Short,'') <> 'N')
   LEFT OUTER JOIN Codelkup CLR1 (NOLOCK) ON (TORD.Storerkey = CLR1.Storerkey AND CLR1.Code = 'SHOWLBISHIP'
                                          AND CLR1.Listname = 'REPORTCFG' AND CLR1.Long = 'r_dw_packing_list_detail' AND ISNULL(CLR1.Short,'') <> 'N')
----CS04 S
   -- LEFT JOIN dbo.PICKDETAIL PID WITH (NOLOCK) ON PID.DropID=packdetail.labelno AND PID.sku=packdetail.sku AND PID.Status='5'
   -- CROSS APPLY( SELECT dropid,sku,(qty) AS qty FROM PICKDETAIL WITH (NOLOCK) WHERE Status='5' AND DropID=packdetail.labelno AND sku=packdetail.sku ) AS pid
--   LEFT JOIN STORER ST (NOLOCK) ON ST.StorerKey = orders.B_Company AND ST.type='4'AND ST.ConsigneeFor='NIKECN' AND ST.Notes1='RSC' 
--   LEFT OUTER JOIN Codelkup CLR2 (NOLOCK) ON (ORDERS.Storerkey = CLR2.Storerkey AND CLR2.Code = 'SHOWCONSIGNEE'
--                                          AND CLR2.Listname = 'REPORTCFG' AND CLR2.Long = 'r_dw_packing_list_detail' AND ISNULL(CLR2.Short,'') <> 'N')
----CS04 E
   WHERE ( RTRIM(TORD.OrderKey) IS NULL OR RTRIM(TORD.OrderKey) = '') AND
         ( TORD.Pickslipno = @c_pickslipno )
   GROUP BY TORD.Loadkey,
            TORD.Pickslipno,
            TORD.CartonNo,
            TORD.Sku,
           -- Packdetail.Qty,
            TORD.PackQty,--CASE WHEN ISNULL(TORD.showconsignee,'') = 'Y' THEN pid.qty ELSE Packdetail.Qty END,  --CS04
            CONVERT(DECIMAL(10,5), ISNULL(PACKINFO.Weight,0)),
            CONVERT(DECIMAL(10,5), ISNULL(PACKINFO.[Cube],0)),
            CONVERT(DECIMAL(10,5), ISNULL(PACKINFOSUM.TotalWeight,0)),
            CONVERT(DECIMAL(10,5), ISNULL(PACKINFOSUM.TotalCube,0)),
            TORD.LabelLine,
            SKU.PackQtyIndicator,
            PACK.PackUOM3,
            TORD.LabelNo,
            CASE WHEN ISNULL(CLR.Code,'') = '' THEN 'N' ELSE 'Y' END,
            CASE WHEN ISNULL(CLR1.Code,'') = '' THEN '' ELSE ('2' + RIGHT(TORD.orderkey,9)) END,    --CS04
            CASE WHEN ISNULL(CLR1.Code,'') = '' THEN 'N' ELSE 'Y' END
           ,CASE WHEN @c_zone <> '' THEN TORD.RefNo ELSE '' END            --CS01
           ,CASE WHEN @c_zone <> '' THEN TORD.RefNo2 ELSE '' END            --CS01
           ,TORD.showconsignee                                                    --CS04
           ,TORD.RSCStorer                                                       --CS04
           ,ISNULL(TORD.ConsigneeKey,'')                                               --CS04
   ORDER BY TORD.CartonNo

--SELECT * FROM #TMP_PACKDET

   IF @c_Zone = ''  --CS02 Start
   BEGIN

      SELECT
          Orderkey
         ,ExternOrderkey
         ,ConsigneeKey
         ,C_Contact1
         ,C_Address1
         ,C_Address2
         ,C_Address3
         ,C_Address4
         ,C_Phone1
         ,DeliveryDate
         ,SKU
         ,CartonNo
         ,PickSlipNo
         ,LoadKey
         ,PackQty
         ,BuyerPO
         ,C_Company
         ,PWGT
         ,PCube
         ,PISTTLWGT
         ,PISTTTLCUBE
         ,LabelLine
         ,PackQtyIndicator
         ,PackUOM3
         ,LabelNo
         ,showfullsku
         ,LBIShipNo
         ,showlbiship
         ,''                           --CS01
         ,showconsignee                --CS04
         ,''                           --CS04
      FROM #TMP_PACKDET AS tp
      ORDER BY CartonNo
   END
   ELSE
   BEGIN
      -- --CS01 Start
       SET @n_cntRefno = 0

       SELECT @n_cntRefno = COUNT(DISTINCT c.code)
       FROM PackDetail (NOLOCK)
       JOIN PackHeader (NOLOCK) ON ( PackDetail.PickSlipNo = PackHeader.PickSlipNo )
       --JOIN LoadplanDetail (NOLOCK) ON ( Packheader.Loadkey = LoadplanDetail.LoadKey )
       --JOIN ORDERS (NOLOCK) ON ( Orders.Orderkey = LoadplanDetail.OrderKey )
	   JOIN  ORDERS (NOLOCK) ON Orders.loadkey = Packheader.loadkey                            --(CS03)
       JOIN SKU (NOLOCK) ON ( PackDetail.Sku = SKU.Sku AND PackDetail.StorerKey = SKU.StorerKey )
       LEFT JOIN PICKDETAIL PD (NOLOCK) ON PD.orderkey = ORDERS.OrderKey
       LEFT JOIN LOC L WITH (NOLOCK) ON L.loc=pd.Loc
       LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'ALLSorting' AND
       C.Storerkey=ORDERS.StorerKey AND C.code2=L.PickZone
       WHERE PackDetail.Pickslipno = @c_PickSlipNo
       AND Packdetail.RefNo<>@c_Zone
      --
       IF @n_cntRefno = 0
       BEGIN
          SELECT @n_cntRefno = COUNT(DISTINCT c.code)
          FROM ORDERS (NOLOCK)
         -- JOIN PackDetail (NOLOCK) ON ( ORDERS.StorerKey = PackDetail.StorerKey )             --CS03
          JOIN PackHeader (NOLOCK) ON ( Packheader.Orderkey = Orders.Orderkey                   --CS03
                                    AND Packheader.Loadkey = Orders.Loadkey
                                    AND Packheader.Consigneekey = Orders.Consigneekey )
           JOIN PackDetail (NOLOCK) ON ( PackDetail.PickSlipNo = PackHeader.PickSlipNo )         --CS03
          LEFT JOIN PICKDETAIL PD (NOLOCK) ON PD.orderkey = ORDERS.OrderKey
          LEFT JOIN LOC L WITH (NOLOCK) ON L.loc=pd.Loc
          LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'ALLSorting' AND
          C.Storerkey=ORDERS.StorerKey AND C.code2=L.PickZone
          WHERE PackDetail.Pickslipno = @c_PickSlipNo
          AND Packdetail.RefNo<>@c_Zone
       END

      SET @c_site = ''

      SELECT @c_site = CASE WHEN ISNULL(c.code,'') <> '' THEN c.code ELSE l.pickzone END
      FROM PackDetail (NOLOCK)
      JOIN PackHeader (NOLOCK) ON ( PackDetail.PickSlipNo = PackHeader.PickSlipNo )
      --JOIN LoadplanDetail (NOLOCK) ON ( Packheader.Loadkey = LoadplanDetail.LoadKey )    --CS03
      --JOIN ORDERS (NOLOCK) ON ( Orders.Orderkey = LoadplanDetail.OrderKey )              --CS03
	  JOIN ORDERS (NOLOCK) ON ( Orders.loadkey = PackHeader.loadkey )                --CS03
      JOIN SKU (NOLOCK) ON ( PackDetail.Sku = SKU.Sku AND PackDetail.StorerKey = SKU.StorerKey )
      LEFT JOIN PICKDETAIL PD (NOLOCK) ON PD.orderkey = ORDERS.OrderKey
      LEFT JOIN LOC L WITH (NOLOCK) ON L.loc=pd.Loc
      LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'ALLSorting' AND C.Storerkey=ORDERS.StorerKey AND C.code2=L.PickZone
      WHERE PackDetail.Pickslipno = @c_PickSlipNo
      AND ISNULL(RTRIM(Packdetail.RefNo),'') <> @c_Zone

      IF @c_site = ''
      BEGIN
         SELECT @c_site = CASE WHEN ISNULL(c.code,'') <> '' THEN c.code ELSE l.pickzone END
         FROM ORDERS (NOLOCK)
         --JOIN PackDetail (NOLOCK) ON ( ORDERS.StorerKey = PackDetail.StorerKey )                 --CS03
         JOIN PackHeader (NOLOCK) ON ( Packheader.Orderkey = Orders.Orderkey                       --CS03
                                    AND Packheader.Loadkey = Orders.Loadkey
                                    AND Packheader.Consigneekey = Orders.Consigneekey )
         JOIN PackDetail (NOLOCK) ON ( PackDetail.PickSlipNo = PackHeader.PickSlipNo )         --CS03
         LEFT JOIN PICKDETAIL PD (NOLOCK) ON PD.orderkey = ORDERS.OrderKey
         LEFT JOIN LOC L WITH (NOLOCK) ON L.loc=pd.Loc
         LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'ALLSorting' AND
         C.Storerkey=ORDERS.StorerKey AND C.code2=L.PickZone
         WHERE PackDetail.Pickslipno = @c_PickSlipNo
         AND ISNULL(RTRIM(Packdetail.RefNo),'') <> @c_Zone
      END
      --CS01 END

      SET @n_NewCartonNo = 1

      DECLARE CUR_ResetCartonNo CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT CartonNo
         FROM #TMP_PACKDET WITH (NOLOCK)
         WHERE Pickslipno = @c_PickSlipNo
         AND ISNULL(RTRIM(RefNo),'') <> @c_Zone
         ORDER BY CartonNo

      OPEN CUR_ResetCartonNo
      FETCH NEXT FROM CUR_ResetCartonNo INTO @n_OriginalCartonNo
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         BEGIN TRAN
         UPDATE #TMP_PACKDET WITH (ROWLOCK)
         SET CartonNo = @n_NewCartonNo
         WHERE Pickslipno = @c_PickSlipNo
         AND ISNULL(RTRIM(RefNo),'') <> @c_Zone
         AND CartonNo = @n_OriginalCartonNo
         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN
            BREAK
         END
         ELSE
         BEGIN
            COMMIT TRAN
         END
         SET @n_NewCartonNo = @n_NewCartonNo + 1
         FETCH NEXT FROM CUR_ResetCartonNo INTO @n_OriginalCartonNo
      END
      CLOSE CUR_ResetCartonNo
      DEALLOCATE CUR_ResetCartonNo

      SELECT
           Orderkey
         , ExternOrderkey
         , ConsigneeKey
         , C_Contact1
         , C_Address1
         , C_Address2
         , C_Address3
         , C_Address4
         , C_Phone1
         , DeliveryDate
         , SKU
         , CASE WHEN ISNULL(RTRIM(RefNo2),'') <> '' THEN ISNULL(RTRIM(RefNo2),'')
                ELSE CartonNo END AS CartonNo
         , PickSlipNo
         ,  CASE WHEN @n_cntRefno >1 THEN @c_RefNo + '-' + LoadKey ELSE loadkey END AS loadkey
         , PackQty
         , BuyerPO
         , C_Company
         , PWGT
         , PCube
         , PISTTLWGT
         , PISTTTLCUBE
         , LabelLine
         , PackQtyIndicator
         , PackUOM3
         , LabelNo
         , showfullsku
         , LBIShipNo
         , showlbiship
         , @c_RefNo --CASE WHEN @n_cntRefno>1 THEN @c_RefNo ELSE '' END AS LSite                       --CS01
         , showconsignee                                                                               --CS04  
         ,CASE WHEN @n_cntRefno >1 THEN @c_RefNo + '-' + tp.PickSlipNo ELSE tp.PickSlipNo END AS prefixpickslipno  --CS04
       FROM #TMP_PACKDET AS tp
       WHERE Pickslipno = @c_PickSlipNo
       AND ISNULL(RTRIM(RefNo),'') <> @c_Zone
       AND ISNULL(RTRIM(RefNo),'') = @c_RefNo
       ORDER BY Pickslipno, CartonNo
   END
END

SET QUOTED_IDENTIFIER OFF

GO