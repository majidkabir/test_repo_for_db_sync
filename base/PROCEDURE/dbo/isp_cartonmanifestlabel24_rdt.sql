SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO



/************************************************************************/
/* Store Procedure:  isp_CartonManifestLabel24_rdt                      */
/* Creation Date: 18-OCT-2017                                           */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose:  WMS-3110 - NIKE content label                              */
/*                                                                      */
/* Input Parameters: Storerkey ,PickSlipNo, CartonNoStart, CartonNoEnd  */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By:  r_dw_carton_manifest_label_24_rdt                        */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 05-Dec-2017  CSCHONG  1.1  WMS-3588 remove orderkey (CS01)           */
/* 10-Jan-2018  CSCHONG  1.2  WMS-3743 revised report logic (CS02)      */
/* 28-Feb-2018  CSCHONG  1.3  WMS-3977 revised field mapping (CS03)     */
/* 25-Jul-2018  LZG      1.4  INC0315824 - Get sum of PackDetail.Qty    */
/*                            separately to cater same SKU separated in */
/*                            OrderDetail (ZG01)                        */
/* 25-Oct-2018  CSCHONG  1.5   Performance tunning (CS04)               */
/* 09-Nov-2018  CSCHONG  1.6   Restructure Scripts (CS05)               */
/* 16-Nov-2018  WLCHOOI  1.7  WMS-6855 Add Packdetail.LabelNo  (WL01)   */
/* 12-APR-2019  CSCHONG  1.8  WMS-8648 add new field (CS06)             */
/* 14-MAY-2019  CSCHONG  1.9  Performance tunning (CS07)                */
/* 28-MAY-2019  TLTING01 1.10  Performance tunning (CS07)               */
/* 12-Jun-2020  TLTING02 1.11  Performance tunning                      */
/* 13-JUL-2022  CSCHONG  1.12  WMS-20223 add report config (CS08)       */
/* 20-Oct-2022  CSCHONG  1.13  Devops Scripts Combine & WMS-20999(CS09) */
/* 13-OCT-2023  CSCHONG  1.14  Performance Tunning (CS10)               */
/************************************************************************/

CREATE   PROC [dbo].[isp_CartonManifestLabel24_rdt] (
       --  @c_StorerKey      NVARCHAR(20)
         @c_PickSlipNo     NVARCHAR(20)
      ,  @c_StartCartonNo  NVARCHAR(20)
      ,  @c_EndCartonNo    NVARCHAR(20)
      ,  @c_RefNo          NVARCHAR(20) = ''          --(CS03)
)
AS
BEGIN

   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF


   DECLARE @c_loadkey         NVARCHAR(50)
         , @c_Ordkey          NVARCHAR(150)
         , @n_cartonno        INT
         , @c_SKU             NVARCHAR(20)
         , @c_putawayzone     NVARCHAR(10)
         , @c_PICtnType       NVARCHAR(10)
         , @n_PDqty           INT
         , @c_Orderkey        NVARCHAR(20)
         , @c_Delimiter       NVARCHAR(1)
         , @n_lineNo          INT
         , @c_Prefix          NVARCHAR(3)
         , @n_CntOrderkey     INT
         , @c_SKUStyle        NVARCHAR(100)
         , @n_CntSize         INT
         , @n_Page            INT
         , @n_PrnQty          INT
         , @n_MaxId           INT
         , @n_MaxRec          INT
         , @n_getPageno       INT
         , @n_MaxLineno       INT
         , @n_CurrentRec      INT
         , @n_qty             INT
         , @n_MaxCartonNo     INT
         , @n_seqno           INT
         , @c_ORDRoute        NVARCHAR(20)
         , @c_busr7           NVARCHAR(30)
         , @c_VNotes2         NVARCHAR(250)
         , @c_vas             NVARCHAR(250)
         , @c_Category        NVARCHAR(20)
         , @c_ODLineNumber    NVARCHAR(5)
         , @c_VNote           NVARCHAR(250)
         , @n_CntVas          INT
         , @c_StorerKey       NVARCHAR(20)
         , @c_Zone            NVARCHAR(30)           --(CS02)
         , @n_cntRefno        INT                    --(CS03)
         , @c_site            NVARCHAR(30)           --(CS03)
         , @n_rowid           INT
         , @c_SHOWDIFFSKUFORMAT NVARCHAR(1) ='N'         --(CS08)


   SET @n_rowid           = 0                        -- ZG01
   SET @c_loadkey         = ''
   SET @c_Ordkey          = ''
   SET @n_cartonno        = 1
   SET @c_SKU             = ''
   SET @c_putawayzone     = ''
   SET @c_PICtnType       = ''
   SET @n_PDqty           = 0
   SET @c_Orderkey        = ''
   SET @c_Delimiter       = ','
   SET @n_lineNo          = 1
   SET @n_CntOrderkey     = 1
   SET @c_SKUStyle        = ''
   SET @n_CntSize         = 1
   SET @n_Page            = 1
   SET @n_PrnQty          = 1
   SET @n_MaxLineno       = 17
   SET @n_qty             = 0
   SET @n_CntVas          = 1

  CREATE TABLE #TMP_CartonLBL24 (
          rowid           int identity(1,1),
          Pickslipno      NVARCHAR(20) NULL,
          loadkey         NVARCHAR(50) NULL,
          orderkey        NVARCHAR(20) NULL,
          sku             NVARCHAR(20) NULL,
          Material        NVARCHAR(20) NULL,
          SKUSIze         NVARCHAR(10) NULL,
          PDQty           INT,
          PageNo          INT,
          VAS             NVARCHAR(250) NULL,      --CS01
          LabelNo         NVARCHAR(40) NULL,       --WL01
          Category        NVARCHAR(150) NULL,     --CS06 Start
          GenderCode      NVARCHAR(150) NULL,
          Division        NVARCHAR(150) NULL)     --CS06 End


  CREATE TABLE #TEMPVAS24DETAIL (
        Pickslipno      NVARCHAR(20) NULL,
        loadkey         NVARCHAR(20) NULL,
        Orderkey        NVARCHAR(20)  NULL,
        SKU             NVARCHAR(20) NULL,
        Notes           NVARCHAR(100) NULL

        )


  SELECT TOP 1 @c_StorerKey = PH.StorerKey
  FROM Packheader PH (NOLOCK)
  WHERE PH.PickSlipNo=@c_PickSlipNo

  /*CS02 Start*/
   SET @c_zone = ''

   SELECT @c_zone = C.code2
   FROM CODELKUP C WITH (NOLOCK)
   WHERE C.LISTNAME='REPORTCFG'
   AND C.Storerkey = @c_storerkey
   AND C.Code = 'ContentFilterByRefNo'
   AND C.Long = 'r_dw_carton_manifest_label_24_rdt'

  /*CS02 END*/

 /*CS08 S*/
   SELECT @c_SHOWDIFFSKUFORMAT =  CASE WHEN ISNULL(CLR.Code,'') <> '' THEN 'Y' ELSE 'N' END      
   FROM CODELKUP CLR WITH (NOLOCK)
   WHERE CLR.LISTNAME='REPORTCFG'
   AND CLR.Storerkey = @c_storerkey
   AND CLR.Code = 'SHOWDIFFSKUFORMAT'
   AND CLR.Long = 'r_dw_carton_manifest_label_24_rdt'
   AND ISNULL(CLR.Short,'') <> 'N'  
 
 /*CS08 E*/

  IF ISNULL(@c_RefNo,'') = ''
  BEGIN
     SELECT TOP 1 @c_RefNo = PD.Refno
  FROM PACKDETAIL PD WITH (NOLOCK)
  WHERE PD.Pickslipno = @c_PickSlipNo
  AND PD.cartonno = CONVERT(INT,@c_StartCartonNo)
  END

    INSERT INTO #TMP_CartonLBL24(Pickslipno,loadkey,orderkey,sku,Material,SKUSize,PDQty,pageno,VAS,LabelNo,      --WL01
                                 Category,GenderCode,Division)     --CS06

   SELECT   DISTINCT Packheader.PickSlipNo,Packheader.loadkey,Orders.orderkey,Packdetail.sku,
                     CASE WHEN ISNULL(@c_SHOWDIFFSKUFORMAT,'') = 'N' THEN LEFT(Packdetail.sku,6) + '-' + SUBSTRING(Packdetail.sku,7,3) ELSE Substring(Packdetail.sku ,1,10) END,     --CS08
                     CASE WHEN ISNULL(@c_SHOWDIFFSKUFORMAT,'') = 'N' THEN SUBSTRING(Packdetail.sku,10,10) ELSE Substring(Packdetail.sku ,12,10) END, Packdetail.Qty AS PDQTY,        -- ZG01     --CS08
                    1 , '',Packdetail.LabelNo   --WL01
                    ,CT.description as Category,CG.description as GenderCode,CD.description as Division --CS06
  FROM Orders Orders WITH (NOLOCK)
  JOIN OrderDetail OrderDetail WITH (NOLOCK) ON Orders.OrderKey = OrderDetail.OrderKey
  --JOIN LoadPlanDetail LoadPlanDetail WITH (NOLOCK) ON (Orders.OrderKey = LoadplanDetail.OrderKey)         --(CS04)
  JOIN Packheader Packheader WITH (NOLOCK) ON (Orders.LoadKey = Packheader.LoadKey)                         --(CS04)
  JOIN Packdetail Packdetail WITH (NOLOCK) ON (Packheader.Pickslipno = Packdetail.pickslipno AND OrderDetail.Storerkey = PackDetail.Storerkey  --tlting01
                           AND OrderDetail.SKU = PackDetail.SKU)
  --CS06 Start
  JOIN SKU S WITH (NOLOCK) ON S.Storerkey = Packdetail.storerkey and S.Sku = Packdetail.sku --and s.itemclass = LEFT(Packdetail.sku,6) + SUBSTRING(Packdetail.sku,7,3)
  LEFT JOIN CODELKUP CT WITH (NOLOCK) ON CT.Listname = 'Category' AND CT.Storerkey = Orders.Storerkey AND CT.code = S.susr4
  LEFT JOIN CODELKUP CG WITH (NOLOCK) ON CG.Listname = 'Gendercode' AND CG.Storerkey = Orders.Storerkey AND CG.code = S.busr4
  LEFT JOIN CODELKUP CD WITH (NOLOCK) ON CD.Listname = 'Division' AND CD.Storerkey = Orders.Storerkey AND CD.code = S.busr7
  --CS06 End
   WHERE Packheader.Pickslipno = @c_PickSlipNo
   AND   Packheader.Storerkey = @c_StorerKey
   AND Packdetail.cartonno between CONVERT(INT,@c_StartCartonNo) AND CONVERT(INT,@c_EndCartonNo)
   and RefNo = @c_RefNo      --CS05
   --and ISNULL(s.itemclass,'') <> ''
   GROUP BY Packheader.PickSlipNo,Packheader.loadkey,Orders.orderkey,Packdetail.sku,--LEFT(Packdetail.sku,6) + '-' + SUBSTRING(Packdetail.sku,7,3),     --CS08 S
           CASE WHEN ISNULL(@c_SHOWDIFFSKUFORMAT,'') = 'N' THEN LEFT(Packdetail.sku,6) + '-' + SUBSTRING(Packdetail.sku,7,3) ELSE Substring(Packdetail.sku ,1,10) END,  
            --SUBSTRING(Packdetail.sku,10,10) , Packdetail.Qty
           CASE WHEN ISNULL(@c_SHOWDIFFSKUFORMAT,'') = 'N' THEN SUBSTRING(Packdetail.sku,10,10) ELSE Substring(Packdetail.sku ,12,10) END, Packdetail.Qty   --CS08 E 
           ,Packdetail.LabelNo --WL01
           ,CT.description,CG.description,CD.description      --CS06
   ORDER BY Packheader.PickSlipNo,Packheader.loadkey,Packdetail.sku

  DECLARE CUR_Labelno CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT Pickslipno
                  ,loadkey
                  ,orderkey
                  ,sku
                  ,rowid               -- ZG01
   FROM #TMP_CartonLBL24 WITH (NOLOCK)
   WHERE Pickslipno = @c_PickSlipNo

   OPEN CUR_Labelno

   FETCH NEXT FROM CUR_Labelno INTO  @c_PickSlipNo
                                    ,@c_loadkey
                                    ,@c_Ordkey
                                    ,@c_SKU
                                    ,@n_rowid

   WHILE @@FETCH_STATUS <> -1
   BEGIN

    SET @n_prnqty = 1
    SET @c_ORDRoute = ''
    SET @c_busr7 = ''
    SET @c_VNotes2 = ''
    SET @n_seqno = 1
    SET @c_vas = ''
    SET @c_Category = ''
    SET @c_ODLineNumber = ''

       SELECT TOP 1 @c_ODLineNumber = OD.OrderLineNumber
       FROM ORDERDETAIL OD WITH (NOLOCK)
       WHERE orderkey=@c_Ordkey
       AND OD.Sku=@c_SKU

       INSERT INTO #TEMPVAS24DETAIL (pickslipno,loadkey,orderkey,sku,notes)
       SELECT @c_PickSlipNo,@c_loadkey,@c_Ordkey,@c_sku,odr.Note1
       FROM orderdetail od (NOLOCK)
       join OrderDetailRef AS odr WITH (NOLOCK) ON odr.OrderLineNumber=od.OrderLineNumber AND odr.Orderkey=od.OrderKey
       WHERE od.OrderKey=@c_Ordkey
       AND odr.OrderLineNumber=@c_ODLineNumber
     --AND pd.PickSlipNo=@c_PickSlipNo
       AND od.sku=@c_sku



   DECLARE CUR_vas CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT  notes
   FROM #TEMPVAS24DETAIL
   WHERE Pickslipno = @c_PickSlipNo
   AND orderkey = @c_Ordkey
   AND sku = @c_sku

   OPEN CUR_vas

   FETCH NEXT FROM CUR_vas INTO @c_VNote
   WHILE @@FETCH_STATUS <> -1
       BEGIN
         IF @c_vas = ''
         BEGIN
             SET @c_vas = CONVERT(NVARCHAR(10),@n_seqno) +'. ' +@c_VNote + CHAR(13)
         END
         ELSE
         BEGIN
            SET @c_vas = @c_vas + CONVERT(NVARCHAR(10),@n_seqno)+'. ' + @c_VNote + CHAR(13)
         END

    SET @n_seqno = @n_seqno + 1

  FETCH NEXT FROM CUR_vas INTO @c_VNote
  END
  CLOSE CUR_vas
  DEALLOCATE CUR_vas


    UPDATE #TMP_CartonLBL24
         SET VAS = RTRIM(@c_vas)
         WHERE orderkey = @c_ordkey
         AND SKU = @c_SKU

   SET @n_lineNo = 1

   DELETE FROM #TEMPVAS24DETAIL
   SET @n_seqno = 1

   FETCH NEXT FROM CUR_Labelno INTO  @c_PickSlipNo
                                    ,@c_loadkey
                                    ,@c_Ordkey
                                    ,@c_SKU
                                    ,@n_rowid
   END
   CLOSE CUR_Labelno
   DEALLOCATE CUR_Labelno

      /*Cs03 Start*/
/*CS10 S*/
--  SET @n_cntRefno = 1

--  SELECT @n_cntRefno = COUNT(DISTINCT c.code)
--       --  ,@c_site = CASE WHEN ISNULL(c.code,'') <> '' THEN c.code ELSE l.pickzone end
--  FROM Orders Orders WITH (NOLOCK)
--  JOIN OrderDetail OrderDetail WITH (NOLOCK) ON Orders.OrderKey = OrderDetail.OrderKey                 --CS07
----  JOIN LoadPlanDetail LoadPlanDetail WITH (NOLOCK) ON (Orders.OrderKey = LoadplanDetail.OrderKey)
--  JOIN Packheader Packheader WITH (NOLOCK) ON (orders.LoadKey = Packheader.LoadKey)
--  JOIN Packdetail Packdetail WITH (NOLOCK) ON Packheader.Pickslipno = Packdetail.pickslipno --AND OrderDetail.SKU = PackDetail.SKU)
--  LEFT JOIN PICKDETAIL PD (NOLOCK) ON PD.orderkey = OrderDetail.OrderKey
--                                   AND PD.orderlinenumber = OrderDetail.orderlinenumber AND PD.SKU = OrderDetail.SKU        --CS07
--  JOIN LOC L WITH (NOLOCK) ON L.loc=pd.Loc
--  JOIN CODELKUP C WITH (NOLOCK) ON C.listname = N'ALLSorting' AND
--   C.Storerkey=ORDERS.StorerKey AND C.code2=L.PickZone
--   WHERE Packheader.Pickslipno = @c_PickSlipNo
--   AND   C.Storerkey = @c_StorerKey  --tlting02


   SELECT  @n_cntRefno = COUNT(DISTINCT c.code)  
   FROM  OrderDetail OrderDetail WITH    (NOLOCK)  
   JOIN Orders Orders WITH (NOLOCK)  ON Orders.Orderkey = OrderDetail.Orderkey
   JOIN PICKDETAIL PD (NOLOCK) ON PD.orderkey = OrderDetail.OrderKey AND PD.orderlinenumber = OrderDetail.orderlinenumber  
   JOIN Loadplandetail LP (NOLOCK) on ( LP.Orderkey = Orders.OrderKey ) 
   JOIN Packheader Packheader WITH    (NOLOCK) ON (LP.LoadKey = Packheader.LoadKey) 
   JOIN Packdetail Packdetail WITH    (NOLOCK) ON Packheader.Pickslipno = Packdetail.pickslipno AND OrderDetail.StorerKey = PackDetail.StorerKey AND   OrderDetail.SKU = PackDetail.SKU  
   JOIN LOC L WITH    (NOLOCK) ON L.loc=pd.Loc 
   JOIN CODELKUP C WITH    (NOLOCK) ON C.listname = N'ALLSorting' AND C.Storerkey=OrderDetail.StorerKey AND C.code2=L.PickZone 
   WHERE Packheader.Pickslipno = @c_PickSlipNo 
   AND Orders.Storerkey = @c_StorerKey

/*CS10 E*/

   IF @n_cntRefno > 1
   BEGIN
    UPDATE #TMP_CartonLBL24
    SET loadkey = ISNULL(@c_RefNo,'') + '-' + Pickslipno   --CS09
    FROM #TMP_CartonLBL24
    WHERE Pickslipno = @c_PickSlipNo
   END
   ELSE    --CS09 S
   BEGIN
    UPDATE #TMP_CartonLBL24
    SET loadkey = Pickslipno   
    FROM #TMP_CartonLBL24
    WHERE Pickslipno = @c_PickSlipNo
   END   --CS09 E

  /*CS03 End*/

  SELECT Pickslipno,loadkey,sku,Material,SKUSize, --removed orderkey
          PDQty AS PDqty,pageno,VAS
         ,LabelNo        --WL01
         ,Category,GenderCode,Division     --CS06
  FROM #TMP_CartonLBL24
  GROUP BY Pickslipno,loadkey,sku,Material,SKUSize,pageno,VAS,PDQty,LabelNo ,Category,GenderCode,Division     --CS06
  ORDER BY loadkey,material,skusize
    --END
 END



GO