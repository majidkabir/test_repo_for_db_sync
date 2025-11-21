SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store Procedure:  isp_UCC_Carton_Label_17_LP                         */    
/* Creation Date: 15-Nov-2010                                           */    
/* Copyright: IDS                                                       */    
/* Written by: NJOW                                                     */    
/*                                                                      */    
/* Purpose:  To print the Ucc Carton Label 17 at Load Plan SOS#195773   */    
/*                                                                      */    
/* Input Parameters: Loadkey                                            */    
/*                                                                      */    
/* Output Parameters:                                                   */  
/*                                                                      */    
/* Usage:                                                               */  
/*                                                                      */    
/* Called By:  isp_UCC_Carton_Label_17_LP                               */    
/*                                                                      */    
/* PVCS Version: 1.1                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author   Ver  Purposes                                  */  
/* 03-Mar-2011  NJOW01   1.0  206942 - Carter PhaseII-Print Carton      */  
/*                            Content label at Component SKU.           */  
/* 14-Nov-2011  YTWan    1.1  SOS#229531 - Add Orderdetail.Userdefine04-*/  
/*                            CustSku. (Wan01)                          */  
/* 21-Oct-2014  CSCHONG  1.2  SOS323142 (CS01)                          */  
/* 13-Jan-2015  CSCHONG  1.3  Set default for SKU.BUSR3 if null (CS02)  */  
/* 25-Mar-2015  CSCHONG  1.4  SOS#337148 Remove update labelno (CS03)   */  
/* 30-Mar-2015  TLTING   1.4  Performance Tune                          */   
/* 20-Apr-2016  CSCHONG  1.5  SOS#368541 Add icon (CS04)                */  
/* 06-Jun-2016  CSCHONG  1.6  SOS#371183 sorting by condition (CS05)    */  
/* 08-Mar-2017  CSCHONG  1.7  WMS-1297 - Add new field (CS06)           */  
/*27-SEP-2017   CSCHONG  1.8  WMS-3055 Revise field mapping (CS07)      */  
/* 28-Jan-2019  TLTING_ext 1.9  enlarge externorderkey field length      */  
/************************************************************************/   
  
CREATE PROC [dbo].[isp_UCC_Carton_Label_17_LP] (  
      @cLoadkey         NVARCHAR(10)  
)  
AS  
BEGIN  
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF   
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
  
DECLARE @n_continue  int,  
        @n_starttcnt int,  
        @b_success  Int,  
        @n_err      Int,  
        @c_errmsg   NVARCHAR(225),  
        @c_mCountry NVARCHAR(30),  
        @c_labelno  NVARCHAR(20),  
        @n_rowref   int,  
        @c_keyname  NVARCHAR(30),  
        @c_orderkey NVARCHAR(10)  
          
/*CS05 Start */  
DECLARE        
        @c_deliveryZone     NVARCHAR(10),   
        @c_ExternOrderkey   NVARCHAR(50),  --tlting_ext  
        @c_buyerpo          NVARCHAR(20),  
        @n_cartonno         INT,  
        @c_loadkey          NVARCHAR(20),  
        @c_style            NVARCHAR(20),  
        @n_qty              INT,  
        @n_RowNo            INT,  
        @n_Cntstyle         INT  
/*CS05 End*/          
  
SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt=@@TRANCOUNT, @c_errmsg='', @n_err=0  
  
WHILE @@TRANCOUNT > 0  
   COMMIT TRAN  
  
/*CS04 start*/  
/*DECLARE CUR_ORDER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
SELECT DISTINCT ORDERS.Orderkey, PACKDETAIL.Labelno, ORDERS.M_Country  
FROM LOADPLANDETAIL (NOLOCK)  
  JOIN ORDERS (NOLOCK) ON (LOADPLANDETAIL.Orderkey = ORDERS.Orderkey)  
  JOIN PACKHEADER (NOLOCK) ON (ORDERS.OrderKey = PACKHEADER.OrderKey)  
  JOIN PACKDETAIL (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)    
WHERE LOADPLANDETAIL.Loadkey = @cLoadkey   
ORDER BY ORDERS.Orderkey, PACKDETAIL.Labelno  
  
OPEN CUR_ORDER    
    
FETCH NEXT FROM CUR_ORDER INTO @c_OrderKey, @c_LabelNo, @c_mCountry  
   
WHILE @@FETCH_STATUS <> -1    
BEGIN    
   BEGIN TRAN   
   IF (SELECT COUNT(1) FROM CARTONTRACK (NOLOCK) WHERE LabelNo = @c_labelno) = 0  
   BEGIN            
     IF @c_mCountry = 'PUR'  
        SET @c_keyname = 'FedExExpress'  
     ELSE  --USA  
        SET @c_keyname = 'FedExGround'  
       
      SELECT @n_RowRef = MIN(CARTONTRACK.RowRef)  
      FROM CARTONTRACK (NOLOCK)  
      WHERE CARTONTRACK.Keyname = @c_keyname  
      AND ISNULL(CARTONTRACK.Labelno,'') = ''  
        
      IF @n_RowRef IS NULL  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_errmsg = 'No empty CartonTrack record found to be updated'  
      END     
      ELSE  
      BEGIN  
         UPDATE CARTONTRACK WITH (ROWLOCK)  
         SET CARTONTRACK.LabelNo = @c_labelno  
         WHERE CARTONTRACK.RowRef = @n_RowRef  
      END        
   END  
     
    WHILE @@TRANCOUNT > 0  
      COMMIT TRAN   
     
   FETCH NEXT FROM CUR_ORDER INTO @c_OrderKey, @c_Labelno, @c_mCountry     
END  
CLOSE CUR_ORDER  
DEALLOCATE CUR_ORDER*/  
  
/*CS04 end*/  
  
BEGIN TRAN  
  
SELECT OD.Orderkey    
               ,OD.Storerkey    
               ,OD.Sku    
               ,ISNULL(MIN(RTRIM(OD.UserDefine04)),'') AS UserDefine04    
INTO #TOD                 
FROM LoadPlanDetail LPD WITH (NOLOCK)    
JOIN OrderDetail OD WITH (NOLOCK) ON (OD.Orderkey = LPD.Orderkey)    
WHERE LPD.Loadkey = @cLoadkey    
GROUP BY OD.Orderkey, OD.Storerkey, OD.Sku  
  
  
/*CS05 start*/  
  
  SET @c_deliveryZone = ''   
  
  SELECT TOP 1 @c_deliveryZone = LP.delivery_zone  
  FROM LOADPLAN LP WITH (NOLOCK)  
  JOIN ORDERS ORD (NOLOCK) ON ORD.LoadKey=LP.LoadKey  
  --JOIN PACKHEADER PH (NOLOCK) ON (ORD.OrderKey = PH.OrderKey)  
  WHERE LP.Loadkey = @cLoadkey   
  
/*CS05 End*/  
  
SELECT ORDERS.ExternOrderkey AS ExternOrderkey,  
   ORDERS.Userdefine02 AS Userdefine02,  
   ORDERS.BuyerPO AS BuyerPO,  
   PACKDETAIL.CartonNo AS CartonNo,          
       PACKDETAIL.LabelNo AS LabelNo,  
       SKU.Style AS Style,                                                          
       SKU.Color AS Color,   
       S2.measurement + CASE WHEN COUNT(SKU.Size) > 1 then '*MIX' ELSE '' END as [Size],--SKU.Size,     --(CS01) --(CS07)  
       --SKU.measurement,                                                                                      --(CS07)  
       TOD.UserDefine04 AS custsku,                                                                           --(Wan01)  
       SUM(BILLOFMATERIAL.Qty * PACKDETAIL.Qty) AS Qty,  
       PACKDETAIL.Qty AS PICKQTY,  
       PACKINFO.Cartontype AS Cartontype,  
       CASE WHEN ISNULL(SKU.BUSR3,'') = '' THEN '99' ELSE SKU.BUSR3 END as SkuZone,             --(CS01)  --(CS02)  
       CASE WHEN ORDERS.C_state = 'CA' THEN CHAR(169) ELSE '' END AS 'c_Icon'                        --(CS04)  
       ,LOADPLANDETAIL.Loadkey AS loadkey                                                            --(CS05)  
       ,0 AS RowNo                                                                                   --(CS05)  
       ,ORDERS.[Stop]                                                                                  --(CS06)   
  INTO #TempUCC17_LP  
  FROM LOADPLANDETAIL (NOLOCK)  
  JOIN ORDERS ORDERS (NOLOCK) ON (LOADPLANDETAIL.Orderkey = ORDERS.Orderkey)  
  JOIN PACKHEADER (NOLOCK) ON (ORDERS.OrderKey = PACKHEADER.OrderKey)  
  JOIN PACKDETAIL (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)    
  JOIN PACKINFO (NOLOCK) ON (PACKDETAIL.Pickslipno = PACKINFO.Pickslipno AND PACKDETAIL.Cartonno = PACKINFO.Cartonno)  
  JOIN BILLOFMATERIAL (NOLOCK) ON (PACKDETAIL.Storerkey = BILLOFMATERIAL.Storerkey   
                                  AND PACKDETAIL.Sku = BILLOFMATERIAL.sku)  
  JOIN SKU (NOLOCK) ON (BILLOFMATERIAL.Storerkey = SKU.Storerkey AND BILLOFMATERIAL.Componentsku = SKU.Sku)  
  JOIN SKU S2 (NOLOCK) ON (PACKDETAIL.Storerkey = S2.Storerkey AND PACKDETAIL.Sku = S2.Sku)          --(CS07)  
  /* (Wan01)- (Start) */  
  JOIN ( SELECT Orderkey  
               ,Storerkey  
               ,Sku  
               ,UserDefine04  
         FROM #TOD) TOD  
  ON (TOD.Orderkey = PackHeader.Orderkey)  
  AND(TOD.Storerkey= Packdetail.Storerkey)  
  AND(TOD.Sku= Packdetail.Sku)  
  /* (Wan01)- (End) */  
 WHERE LOADPLANDETAIL.Loadkey = @cLoadkey   
 AND @n_continue <> 3  
GROUP BY ORDERS.ExternOrderkey,  
   ORDERS.Userdefine02,  
   ORDERS.BuyerPO,  
   PACKDETAIL.CartonNo,          
       PACKDETAIL.LabelNo,  
       SKU.Style,                                                                   
       SKU.Color,   
      -- SKU.Size,                                                                                 --(CS01)  
       S2.measurement,                                                                            --(CS07)  
       TOD.UserDefine04,                                                                           --(Wan01)  
       PACKDETAIL.Qty,  
       PACKINFO.Cartontype,   
       CASE WHEN ISNULL(SKU.BUSR3,'') = '' THEN '99' ELSE SKU.BUSR3 END ,                 --(CS01)  --(CS02  
     ORDERS.C_state                                                                                --(CS04)  
     ,LOADPLANDETAIL.Loadkey                                                            --(CS05)  
     /*CS05 start*/  
     ,ORDERS.[Stop]                                                                                  --(CS06)   
   ORDER BY   
   ORDERS.ExternOrderkey,buyerpo,cartonno,(SKU.Style),PACKDETAIL.Qty  
  -- CASE WHEN @c_deliveryZone = '1' THEN ORDERS.ExternOrderkey END ASC,buyerpo,cartonno, (SKU.Style),  
  -- CASE WHEN @c_deliveryZone <> '1' THEN  (SKU.Style) END ASC,PACKDETAIL.Qty  
   /*CS05 End*/  
      
   WHILE @@TRANCOUNT > 0  
      COMMIT TRAN   
          
      WHILE @@TRANCOUNT < @n_starttcnt   
      BEGIN TRAN  
        
        
      -- IF @c_deliveryZone = '1'  
      --BEGIN  
      --  SELECT * FROM #TempUCC17_LP  
      --  ORDER BY ExternOrderkey,buyerpo,style,qty  
      --END  
      --ELSE  
      --BEGIN  
      -- SELECT * FROM #TempUCC17_LP  
      -- ORDER BY style,qty,labelno,cartonNo  
      --END   
        
      /*CS05 start*/  
       
      IF ISNULL(@c_deliveryZone,'0') = '0' OR @c_deliveryZone=''  
      BEGIN  
       SET @n_RowNo = 1  
             
       DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
    SELECT DISTINCT externorderkey,buyerpo,cartonNo,labelno,min(style),qty--,COUNT(style)       
    FROM   #TempUCC17_LP     
    WHERE loadkey =@cloadkey   
    GROUP BY externorderkey,buyerpo,cartonNo,labelno,qty  
    ORDER BY min(style),qty DESC,labelno  
    
    OPEN CUR_RESULT     
       
    FETCH NEXT FROM CUR_RESULT INTO @c_externorderkey,@c_buyerpo,@n_cartonno,@c_labelno,@c_style,@n_qty --,@n_Cntstyle   
       
    WHILE @@FETCH_STATUS <> -1    
    BEGIN   
       
     UPDATE #TempUCC17_LP   
     SET RowNo = @n_RowNo  
     WHERE loadkey = @cloadkey  
     AND ExternOrderkey= @c_ExternOrderkey  
     AND buyerpo = @c_buyerpo      
     AND labelno = @c_labelno  
     AND CartonNo =@n_cartonno  
     AND Rowno=0  
       
       
     SET @n_RowNo = @n_RowNo + 1  
       
    FETCH NEXT FROM CUR_RESULT INTO @c_externorderkey,@c_buyerpo,@n_cartonno,@c_labelno,@c_style,@n_qty  --,@n_Cntstyle    
            END       
    
       SELECT * FROM #TempUCC17_LP   
       ORDER BY RowNo,style,size,qty                  --(CS07)  
      END  
      ELSE  
       BEGIN  
        SELECT * FROM #TempUCC17_LP  
        ORDER BY externorderkey,labelno,style,size,qty                --(CS07)  
       END  
        
      /*CS05 End*/  
          
  
  
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_UCC_Carton_Label_17_LP'  
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
END  
  

GO