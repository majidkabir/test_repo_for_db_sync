SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store Procedure:  isp_CartonManifestLabel30_rdt                      */    
/* Creation Date: 21-NOV-2018                                           */    
/* Copyright: IDS                                                       */    
/* Written by: CSCHONG                                                  */    
/*                                                                      */    
/* Purpose:  WMS-7043 - CN NIKE CTR content label                       */    
/*                                                                      */    
/* Input Parameters: Storerkey ,PickSlipNo, CartonNoStart, CartonNoEnd  */    
/*                                                                      */    
/* Output Parameters:                                                   */    
/*                                                                      */    
/* Usage:                                                               */    
/*                                                                      */    
/* Called By:  r_dw_carton_manifest_label_30_rdt                        */    
/*                                                                      */    
/* PVCS Version: 1.1                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author   Ver  Purposes                                  */    
/************************************************************************/    
    
CREATE PROC [dbo].[isp_CartonManifestLabel30_rdt] (    
       --  @c_StorerKey      NVARCHAR(20)    
         @c_PickSlipNo     NVARCHAR(20)    
      ,  @c_StartCartonNo  NVARCHAR(20)    
      ,  @c_EndCartonNo    NVARCHAR(20)    
      ,  @c_RefNo          NVARCHAR(20) = ''               
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
         , @n_CntVas INT    
         , @c_StorerKey       NVARCHAR(20)    
         , @c_Zone            NVARCHAR(30)                
         , @n_cntRefno        INT                         
         , @c_site            NVARCHAR(30)                
         , @n_rowid           INT  
         , @c_sku_susr3       NVARCHAR(30)    
    
    
   SET @n_rowid           = 0                              
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
   SET @c_sku_susr3       = ''  
    
  CREATE TABLE #TMP_CartonLBL30 (    
          rowid           int identity(1,1),    
          Pickslipno      NVARCHAR(20) NULL,    
          loadkey         NVARCHAR(50) NULL,    
          orderkey        NVARCHAR(20) NULL,    
          sku             NVARCHAR(20) NULL,    
          Material        NVARCHAR(20) NULL,    
          SKUSIze         NVARCHAR(10) NULL,    
          PDQty           INT,    
          PageNo          INT,    
          VAS             NVARCHAR(250) NULL,  
          labelno         NVARCHAR(20) NULL,  
          SUSR3           NVARCHAR(30) NULL)                  
    
  CREATE TABLE #TEMPVAS30DETAIL (    
        Pickslipno      NVARCHAR(20) NULL,    
        loadkey         NVARCHAR(20) NULL,    
        Orderkey        NVARCHAR(20)  NULL,    
        SKU             NVARCHAR(20) NULL,    
        Notes           NVARCHAR(100) NULL,  
        SUSR3           NVARCHAR(30) NULL    
        )    
    
    
  SELECT TOP 1 @c_StorerKey = PH.StorerKey    
  FROM Packheader PH (NOLOCK)    
  WHERE PH.PickSlipNo=@c_PickSlipNo    
    
   SET @c_zone = ''    
    
   SELECT @c_zone = C.code2    
   FROM CODELKUP C WITH (NOLOCK)    
   WHERE C.LISTNAME='REPORTCFG'    
   AND C.Storerkey = @c_storerkey    
   AND C.Code = 'ContentFilterByRefNo'    
   AND C.Long = 'r_dw_carton_manifest_label_30_rdt'    
    
  
  IF ISNULL(@c_RefNo,'') = ''  
  BEGIN  
     SELECT TOP 1 @c_RefNo = PD.Refno  
     FROM PACKDETAIL PD WITH (NOLOCK)  
     WHERE PD.Pickslipno = @c_PickSlipNo  
     AND PD.cartonno = CONVERT(INT,@c_StartCartonNo)  
  END  
    
    INSERT INTO #TMP_CartonLBL30(Pickslipno,loadkey,orderkey,sku,Material,SKUSize,PDQty,pageno,VAS,labelno,susr3 )    
    
   SELECT   DISTINCT Packheader.PickSlipNo,Packheader.loadkey,Orders.orderkey,Packdetail.sku,    
                     LEFT(Packdetail.sku,6) + '-' + SUBSTRING(Packdetail.sku,7,3),    
                     SUBSTRING(Packdetail.sku,10,10), Packdetail.Qty AS PDQTY,                        
                     1 , '' ,Packdetail.labelno,''   
  FROM Orders Orders WITH (NOLOCK)    
  JOIN OrderDetail OrderDetail WITH (NOLOCK) ON Orders.OrderKey = OrderDetail.OrderKey     
  JOIN Packheader Packheader WITH (NOLOCK) ON (Orders.LoadKey = Packheader.LoadKey)                              
  JOIN Packdetail Packdetail WITH (NOLOCK) ON (Packheader.Pickslipno = Packdetail.pickslipno AND OrderDetail.SKU = PackDetail.SKU)    
  WHERE Packheader.Pickslipno = @c_PickSlipNo    
  AND   Packheader.Storerkey = @c_StorerKey    
  AND Packdetail.cartonno between CONVERT(INT,@c_StartCartonNo) AND CONVERT(INT,@c_EndCartonNo)     
  and RefNo = @c_RefNo         
  GROUP BY Packheader.PickSlipNo,Packheader.loadkey,Orders.orderkey,Packdetail.sku,LEFT(Packdetail.sku,6) + '-' + SUBSTRING(Packdetail.sku,7,3),    
           SUBSTRING(Packdetail.sku,10,10) , Packdetail.Qty,Packdetail.labelno  
  ORDER BY Packheader.PickSlipNo,Packheader.loadkey,Packdetail.sku   
    
  DECLARE CUR_Labelno CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT DISTINCT Pickslipno    
                  ,loadkey    
                  ,orderkey    
                  ,sku    
                  ,rowid                    
   FROM #TMP_CartonLBL30 WITH (NOLOCK)    
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
    SET @c_sku_susr3 = ''    
    
       SELECT TOP 1 @c_ODLineNumber = OD.OrderLineNumber    
       FROM ORDERDETAIL OD WITH (NOLOCK)    
       WHERE orderkey=@c_Ordkey    
       AND OD.Sku=@c_SKU    
  
       SELECT TOP 1 @c_sku_susr3 = S.SUSR3  
       From SKU S WITH (NOLOCK)  
       WHERE s.storerkey = @c_StorerKey  
       AND S.sku =  @c_SKU  
  
       INSERT INTO #TEMPVAS30DETAIL (pickslipno,loadkey,orderkey,sku,notes,SUSR3)    
       SELECT @c_PickSlipNo,@c_loadkey,@c_Ordkey,@c_sku,odr.Note1 ,@c_sku_susr3   
       FROM orderdetail od (NOLOCK)    
       join OrderDetailRef AS odr WITH (NOLOCK) ON odr.OrderLineNumber=od.OrderLineNumber AND odr.Orderkey=od.OrderKey    
       WHERE od.OrderKey=@c_Ordkey    
       AND odr.OrderLineNumber=@c_ODLineNumber    
       --AND pd.PickSlipNo=@c_PickSlipNo    
       AND od.sku=@c_sku    
    
    
    
   DECLARE CUR_vas CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT  notes    
   FROM #TEMPVAS30DETAIL    
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
    
    
    UPDATE #TMP_CartonLBL30    
         SET VAS = RTRIM(@c_vas)   
             ,susr3 = @c_sku_susr3   
         WHERE orderkey = @c_ordkey    
         AND SKU = @c_SKU    
    
   SET @n_lineNo = 1    
    
   DELETE FROM #TEMPVAS30DETAIL    
   SET @n_seqno = 1    
    
   FETCH NEXT FROM CUR_Labelno INTO  @c_PickSlipNo    
                                    ,@c_loadkey    
                                    ,@c_Ordkey    
                                    ,@c_SKU    
                                    ,@n_rowid    
   END    
   CLOSE CUR_Labelno    
   DEALLOCATE CUR_Labelno    
    
       
  SELECT Pickslipno,loadkey,sku,Material,SKUSize, --removed orderkey    
         PDQty AS PDqty,pageno,VAS,labelno,SUSR3    
  FROM #TMP_CartonLBL30    
  GROUP BY Pickslipno,loadkey,sku,Material,SKUSize,pageno,VAS,PDQty,labelno,SUSR3    
  ORDER BY loadkey,material,skusize    
    --END    
 END    
  

GO