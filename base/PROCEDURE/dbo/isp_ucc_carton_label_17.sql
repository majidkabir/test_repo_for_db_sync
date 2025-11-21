SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store Procedure:  isp_UCC_Carton_Label_17                            */    
/* Creation Date: 02-Apr-2010                                           */    
/* Copyright: IDS                                                       */    
/* Written by: NJOW                                                     */    
/*                                                                      */    
/* Purpose:  To print the Ucc Carton Label 17                           */    
/*                                                                      */    
/* Input Parameters: Storerkey ,PickSlipNo, CartonNoStart, CartonNoEnd  */    
/*                                                                      */    
/* Output Parameters:                                                   */  
/*                                                                      */    
/* Usage:                                                               */  
/*                                                                      */    
/* Called By:  r_dw_ucc_carton_label_17                                 */    
/*                                                                      */    
/* PVCS Version: 1.2                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author   Ver  Purposes                                  */  
/* 03-Mar-2011  NJOW01   1.0  206942 - Carter PhaseII-Print Carton      */  
/*                            Content label at Component SKU.           */  
/* 14-Nov-2011  YTWan    1.2  SOS#229531 - Add Orderdetail.Userdefine04-*/  
/*                            CustSku. (Wan01)                          */  
/* 21-Oct-2014  CSCHONG  1.3  SOS323142 (CS01)                          */  
/* 13-Jan-2015  CSCHONG  1.3  Set default for SKU.BUSR3 if null (CS02)  */  
/* 25-Mar-2015  CSCHONG  1.4  SOS#337148 Remove update labelno (CS03)   */  
/* 20-Apr-2016  CSCHONG  1.5  SOS#368541 Add icon (CS04)                */  
/* 06-Jun-2016  CSCHONG  1.6  SOS#371183 sorting by condition (CS05)    */  
/* 08-Mar-2017  CSCHONG  1.7  WMS-1297 - Add new field (CS06)           */  
/*27-SEP-2017   CSCHONG  1.8  WMS-3055 Revise field mapping (CS07)      */  
/************************************************************************/    
  
CREATE PROC [dbo].[isp_UCC_Carton_Label_17] (  
      @cStorerKey        NVARCHAR(15),  
      @cPickSlipNo       NVARCHAR(10),  
      @cStartCartonNo    NVARCHAR(10),  
      @cEndCartonNo      NVARCHAR(10)    
)  
AS  
BEGIN  
  
   SET NOCOUNT ON  
   SET ANSI_DEFAULTS OFF    
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
        @c_deliveryZone NVARCHAR(10)     --(CS05)  
          
  
SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt=@@TRANCOUNT, @c_errmsg='', @n_err=0  
/* CS03 start  
IF NOT EXISTS(SELECT PACKDETAIL.Labelno  
             FROM PACKDETAIL (NOLOCK)   
             JOIN CARTONTRACK (NOLOCK) ON (PACKDETAIL.Labelno = CARTONTRACK.Labelno)  
             WHERE PACKDETAIL.Pickslipno = @cPickslipno  
             AND PACKDETAIL.Cartonno = CAST(@cStartCartonNo as int))  
BEGIN  
  SELECT @c_mCountry = ORDERS.M_Country  
  FROM PACKHEADER (NOLOCK)   
  JOIN ORDERS (NOLOCK) ON (PACKHEADER.Orderkey = ORDERS.Orderkey)    WHERE PACKHEADER.Pickslipno = @cPickslipno  
    
  SELECT TOP 1 @c_labelno = PACKDETAIL.Labelno  
   FROM PACKDETAIL (NOLOCK)   
   WHERE PACKDETAIL.Pickslipno = @cPickslipno  
   AND PACKDETAIL.Cartonno = CAST(@cStartCartonNo as int)  
    
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
END */  
/*CS03 End*/  
  
/*CS05 start*/  
  
  SET @c_deliveryZone = ''   
  
  SELECT TOP 1 @c_deliveryZone = LP.delivery_zone  
  FROM LOADPLAN LP WITH (NOLOCK)  
  JOIN ORDERS ORD (NOLOCK) ON ORD.LoadKey=LP.LoadKey  
  JOIN PACKHEADER PH (NOLOCK) ON (ORD.OrderKey = PH.OrderKey)  
  WHERE PH.PickSlipNo = @cPickSlipNo  
  
/*CS05 End*/  
  
SELECT ORDERS.ExternOrderkey,  
   ORDERS.Userdefine02,  
   ORDERS.BuyerPO,  
   PACKDETAIL.CartonNo,          
       PACKDETAIL.LabelNo,  
       SKU.Style,                                                                   
       SKU.Color,   
       S2.Measurement + CASE WHEN COUNT(SKU.Size) > 1 then '*MIX' ELSE '' END as [Size],--SKU.Size,           --(CS01) --CS07  
       --SKU.Measurement as [Size],                                                                          --(CS07)  
       TOD.UserDefine04 as cntsku,                                                                 --(Wan01)  
       SUM(BILLOFMATERIAL.Qty * PACKDETAIL.Qty) AS Qty,  
       PACKDETAIL.Qty AS PICKQTY,  
       PACKINFO.Cartontype,  
       CASE WHEN ISNULL(SKU.BUSR3,'') = '' THEN '99' ELSE SKU.BUSR3 END as skuzone,                  --(CS02)  
       CASE WHEN ORDERS.C_state = 'CA' THEN CHAR(169) ELSE '' END AS 'c_Icon',                        --(CS04)    
       ORDERS.[Stop]                                                                                  --(CS06)                                                                  --(CS04)  
  FROM ORDERS (NOLOCK)   
  JOIN PACKHEADER (NOLOCK) ON (ORDERS.OrderKey = PACKHEADER.OrderKey)  
  JOIN PACKDETAIL (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)    
  JOIN PACKINFO (NOLOCK) ON (PACKDETAIL.Pickslipno = PACKINFO.Pickslipno AND PACKDETAIL.Cartonno = PACKINFO.Cartonno)  
  JOIN BILLOFMATERIAL (NOLOCK) ON (PACKDETAIL.Storerkey = BILLOFMATERIAL.Storerkey   
                                  AND PACKDETAIL.Sku = BILLOFMATERIAL.Sku)  
  JOIN SKU (NOLOCK) ON (BILLOFMATERIAL.Storerkey = SKU.Storerkey AND BILLOFMATERIAL.ComponentSku = SKU.Sku)  
  JOIN SKU S2 (NOLOCK) ON (PACKDETAIL.Storerkey = S2.Storerkey AND PACKDETAIL.Sku = S2.Sku)          --CS07  
  /* (Wan01)- (Start) */  
  JOIN ( SELECT OD.Orderkey  
               ,OD.Storerkey  
               ,OD.Sku  
               ,ISNULL(MIN(RTRIM(OD.UserDefine04)),'') AS UserDefine04  
         FROM PackHeader PH WITH (NOLOCK)  
         JOIN OrderDetail OD WITH (NOLOCK) ON (OD.Orderkey = PH.Orderkey)  
         WHERE PH.StorerKey = @cStorerKey   
           AND PH.PickSlipNo= @cPickSlipNo   
         GROUP BY OD.Orderkey, OD.Storerkey, OD.Sku) TOD  
  ON (TOD.Orderkey = PackHeader.Orderkey)  
  AND(TOD.Storerkey= Packdetail.Storerkey)  
  AND(TOD.Sku= Packdetail.Sku)  
  /* (Wan01)- (End) */  
 WHERE ORDERS.StorerKey = @cStorerKey   
 AND PACKHEADER.PickSlipNo = @cPickSlipNo   
 AND PACKDETAIL.CartonNo BETWEEN CAST(@cStartCartonNo as int) AND CAST(@cEndCartonNo as Int)   
 AND @n_continue <> 3  
GROUP BY ORDERS.ExternOrderkey,  
   ORDERS.Userdefine02,  
   ORDERS.BuyerPO,  
   PACKDETAIL.CartonNo,          
       PACKDETAIL.LabelNo,  
       SKU.Style,                                                                   
       SKU.Color,   
       S2.Measurement, --SKU.Size,                                                             --(CS01)   --CS07  
       TOD.UserDefine04,                                                                           --(Wan01)  
       PACKDETAIL.Qty,  
       PACKINFO.Cartontype,  
       CASE WHEN ISNULL(SKU.BUSR3,'') = '' THEN '99' ELSE SKU.BUSR3 END,                          --(CS02)  
       ORDERS.C_state                                                                                --(CS04)  
       /*CS05 start*/  
        ,ORDERS.[Stop]                                                                --(CS06)  
   ORDER BY   
   CASE WHEN ISNULL(@c_deliveryZone,'0') = '1' THEN ORDERS.ExternOrderkey END ASC, PACKDETAIL.CartonNo,(SKU.Style),  
   CASE WHEN ISNULL(@c_deliveryZone,'0') <> '1' THEN  (SKU.Style) END ASC,S2.Measurement,PACKDETAIL.Qty              --(CS07)  
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_UCC_Carton_Label_17'  
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