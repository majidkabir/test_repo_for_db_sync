SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/****************************************************************************/    
/* Store Procedure:  nsp_GetPackSlipNike02                                  */    
/* Creation Date: 09-Nov-2022                                               */    
/* Copyright: IDS                                                           */    
/* Written by: Mingle                                                       */    
/*                                                                          */    
/* Purpose:  WMS-21090 [TW] NIK B2B Packing List New                        */    
/*                                                                          */    
/* Usage:  Used for report dw = r_dw_print_nike_packlist_02                 */    
/*                                                                          */    
/* Called By:                                                               */    
/*                                                                          */    
/* PVCS Version:                                                            */    
/*                                                                          */    
/* Version:                                                                 */    
/*                                                                          */    
/* Updates:                                                                 */    
/* Date         Author   Ver. Purposes                                      */    
/* 09-Nov-2022  Mingle   1.0  DevOps Combine Script(Created)                */    
/****************************************************************************/    
    
CREATE   PROC [dbo].[nsp_GetPackSlipNike02] (@c_Pickslipno nvarchar(10))    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
   DECLARE @b_debug int    
   SELECT @b_debug = 0    
    
   DECLARE --@c_PickSlipNo        nvarchar(10),    
         @c_OrderKey        nvarchar(10),    
         @c_SkuSize         nvarchar(5),    
         @c_TempOrderKey       nvarchar(10),    
         @c_TempSize        nvarchar(5),    
         @n_TempQty         int,    
         @c_PrevOrderKey       nvarchar(10),    
         @b_success         int,    
         @n_err             int,    
         @c_errmsg          nvarchar(255),    
         @n_Count           int,    
         @c_Column          nvarchar(10),    
         @c_SkuSize1        nvarchar(5),    
         @c_SkuSize2        nvarchar(5),    
         @c_SkuSize3        nvarchar(5),    
         @c_SkuSize4        nvarchar(5),    
         @c_SkuSize5        nvarchar(5),    
         @c_SkuSize6        nvarchar(5),    
         @c_SkuSize7        nvarchar(5),    
         @c_SkuSize8        nvarchar(5),    
         @c_SkuSize9        nvarchar(5),    
         @c_SkuSize10         nvarchar(5),    
         @c_SkuSize11         nvarchar(5),    
         @c_SkuSize12         nvarchar(5),    
         @c_SkuSize13         nvarchar(5),    
         @c_SkuSize14         nvarchar(5),    
         @c_SkuSize15         nvarchar(5),    
         @c_SkuSize16         nvarchar(5),    
         @c_SkuSize17         nvarchar(5),    
         @c_SkuSize18         nvarchar(5),    
         @c_SkuSize19         nvarchar(5),    
         @c_SkuSize20         nvarchar(5),    
         @c_SkuSize21         nvarchar(5),    
         @c_SkuSize22         nvarchar(5),    
         @c_SkuSize23         nvarchar(5),    
         @c_SkuSize24         nvarchar(5),    
         @c_SkuSize25         nvarchar(5),    
         @c_SkuSize26         nvarchar(5),    
         @c_SkuSize27         nvarchar(5),    
         @c_SkuSize28         nvarchar(5),    
         @c_SkuSize29         nvarchar(5),    
         @c_SkuSize30         nvarchar(5),    
         @c_SkuSize31         nvarchar(5),    
         @c_SkuSize32         nvarchar(5),    
         @c_Carton            float,    
         @C_BUSR6             nvarchar(30),    
      -- SOS41626    
        @c_BUSR6_01        nvarchar(30),    
        @c_BUSR6_02        nvarchar(30),    
        @c_BUSR6_03        nvarchar(30),    
        @c_BUSR6_04        nvarchar(30),    
        @c_BUSR6_05        nvarchar(30),    
        @c_BUSR6_06        nvarchar(30),    
        @c_BUSR6_07        nvarchar(30),    
        @c_BUSR6_08        nvarchar(30),    
        @c_BUSR6_09        nvarchar(30),    
        @c_BUSR6_10        nvarchar(30),    
        @c_BUSR6_11        nvarchar(30),    
        @c_BUSR6_12        nvarchar(30),    
        @c_BUSR6_13        nvarchar(30),    
        @c_BUSR6_14        nvarchar(30),    
        @c_BUSR6_15        nvarchar(30),    
        @c_BUSR6_16        nvarchar(30),    
        @c_BUSR6_17        nvarchar(30),    
        @c_BUSR6_18        nvarchar(30),    
        @c_BUSR6_19        nvarchar(30),    
        @c_BUSR6_20        nvarchar(30),    
        @c_BUSR6_21        nvarchar(30),    
        @c_BUSR6_22        nvarchar(30),    
        @c_BUSR6_23        nvarchar(30),    
        @c_BUSR6_24        nvarchar(30),    
        @c_BUSR6_25        nvarchar(30),    
        @c_BUSR6_26        nvarchar(30),    
        @c_BUSR6_27        nvarchar(30),    
        @c_BUSR6_28        nvarchar(30),    
        @c_BUSR6_29        nvarchar(30),    
        @c_BUSR6_30        nvarchar(30),    
        @c_BUSR6_31        nvarchar(30),    
        @c_BUSR6_32        nvarchar(30),    
        @c_SkuSize33       nvarchar(5),           
        @c_SkuSize34       nvarchar(5),           
        @c_SkuSize35       nvarchar(5),           
        @c_SkuSize36       nvarchar(5)            
        ,@c_size              nvarchar(20)           
        ,@c_MoreField         NVarchar(30)           
        ,@c_ODLoadkey     nvarchar(20)    
    
    
    CREATE TABLE #TempPickSlip    
   (PickSlipNo      NVARCHAR(10) NULL,    
    Loadkey         NVARCHAR(10) NULL,    
    OrderKey        NVARCHAR(10) NULL,    
    ExternOrderKey NVARCHAR(50) NULL,       
    ExternPOkey     NVARCHAR(30) NULL,    
    Notes           NVARCHAR(255) NULL,    
    ConsigneeKey    NVARCHAR(15) NULL,    
    Company         NVARCHAR(45) NULL,    
    c_Address1      NVARCHAR(45) NULL,    
    c_Address2      NVARCHAR(45) NULL,    
    c_Address3      NVARCHAR(45) NULL,    
    C_City          NVARCHAR(45) NULL,    
    C_Zip           NVARCHAR(18) NULL,    
    Userdefine06    DATETIME NULL,    
    Type            NVARCHAR(10) NULL,    
    CodelkupDesc    NVARCHAR(250) NULL,    
    Sku             NVARCHAR(20) NULL,    
    UOM             NVARCHAR(10) NULL,    
    CaseCnt         FLOAT,    
    TotCarton       FLOAT,    
    SkuSize1        NVARCHAR(5) NULL,    
    SkuSize2        NVARCHAR(5) NULL,    
    SkuSize3        NVARCHAR(5) NULL,    
    SkuSize4        NVARCHAR(5) NULL,    
    SkuSize5        NVARCHAR(5) NULL,    
    SkuSize6        NVARCHAR(5) NULL,    
    SkuSize7        NVARCHAR(5) NULL,    
    SkuSize8        NVARCHAR(5) NULL,    
    SkuSize9        NVARCHAR(5) NULL,    
    SkuSize10       NVARCHAR(5) NULL,    
    SkuSize11       NVARCHAR(5) NULL,    
    SkuSize12       NVARCHAR(5) NULL,    
    SkuSize13       NVARCHAR(5) NULL,    
    SkuSize14       NVARCHAR(5) NULL,    
    SkuSize15       NVARCHAR(5) NULL,    
    SkuSize16       NVARCHAR(5) NULL,    
    SkuSize17       NVARCHAR(5) NULL,    
    SkuSize18       NVARCHAR(5) NULL,    
    SkuSize19       NVARCHAR(5) NULL,    
    SkuSize20       NVARCHAR(5) NULL,    
    SkuSize21       NVARCHAR(5) NULL,    
    SkuSize22       NVARCHAR(5) NULL,    
    SkuSize23       NVARCHAR(5) NULL,    
    SkuSize24       NVARCHAR(5) NULL,    
    SkuSize25       NVARCHAR(5) NULL,    
    SkuSize26       NVARCHAR(5) NULL,    
    SkuSize27       NVARCHAR(5) NULL,    
    SkuSize28       NVARCHAR(5) NULL,    
    SkuSize29       NVARCHAR(5) NULL,    
    SkuSize30       NVARCHAR(5) NULL,    
    SkuSize31       NVARCHAR(5) NULL,    
    SkuSize32       NVARCHAR(5) NULL,    
    Qty1            INT      NULL,    
    Qty2            INT      NULL,    
    Qty3   INT      NULL,    
    Qty4            INT      NULL,    
    Qty5            INT      NULL,    
    Qty6            INT      NULL,    
    Qty7            INT      NULL,    
    Qty8            INT      NULL,    
    Qty9            INT      NULL,    
    Qty10           INT      NULL,    
    Qty11           INT      NULL,    
    Qty12           INT      NULL,    
    Qty13           INT      NULL,    
    Qty14           INT      NULL,    
    Qty15           INT      NULL,    
    Qty16           INT      NULL,    
    Qty17           INT      NULL,    
    Qty18           INT      NULL,    
    Qty19           INT      NULL,    
    Qty20           INT      NULL,    
    Qty21           INT      NULL,    
    Qty22           INT      NULL,    
    Qty23           INT      NULL,    
    Qty24           INT      NULL,    
    Qty25           INT      NULL,    
    Qty26           INT      NULL,    
    Qty27           INT      NULL,    
    Qty28           INT      NULL,    
    Qty29           INT      NULL,    
    Qty30           INT      NULL,    
    Qty31           INT      NULL,    
    Qty32           INT      NULL,    
    StorerAdd1      NVARCHAR(45) NULL,    
    StorerAdd2      NVARCHAR(45) NULL,    
    StorerPhone1    NVARCHAR(18) NULL,    
    StorerCompany   NVARCHAR(45) NULL,    
    SkuSize33       NVARCHAR(5) NULL,              
    SkuSize34       NVARCHAR(5) NULL,    
    SkuSize35       NVARCHAR(5) NULL,    
    SkuSize36       NVARCHAR(5) NULL,    
    Qty33           INT      NULL,    
    Qty34           INT      NULL,    
    Qty35           INT      NULL,    
    Qty36           INT      NULL,    
    MoreField       NVARCHAR(30) NULL,                
    B_Company       nvarchar(45) NULL,          
    DropID     NVARCHAR(20))    
    
   SELECT @c_TempOrderKey = '', @n_Count = 0    
   SELECT @c_SkuSize1='',  @c_SkuSize2='',  @c_SkuSize3='',  @c_SkuSize4=''    
   SELECT @c_SkuSize5='',  @c_SkuSize6='',  @c_SkuSize7='',  @c_SkuSize8=''    
   SELECT @c_SkuSize9='',  @c_SkuSize10='', @c_SkuSize11='', @c_SkuSize12=''    
   SELECT @c_SkuSize13='', @c_SkuSize14='', @c_SkuSize15='', @c_SkuSize16=''    
   SELECT @c_SkuSize17='', @c_SkuSize18='', @c_SkuSize19='', @c_SkuSize20=''    
   SELECT @c_SkuSize21='', @c_SkuSize22='', @c_SkuSize23='', @c_SkuSize24=''    
   SELECT @c_SkuSize25='', @c_SkuSize26='', @c_SkuSize27='', @c_SkuSize28=''    
   SELECT @c_SkuSize29='', @c_SkuSize30='', @c_SkuSize31='', @c_SkuSize32=''    
   SELECT @c_SkuSize33='', @c_SkuSize34='', @c_SkuSize35='', @c_SkuSize36=''             
   SELECT @c_MoreField = ''    
    
    
       
   SELECT @c_BUSR6_01='', @c_BUSR6_02='', @c_BUSR6_03='', @c_BUSR6_04=''    
   SELECT @c_BUSR6_05='', @c_BUSR6_06='', @c_BUSR6_07='', @c_BUSR6_08=''    
   SELECT @c_BUSR6_09='', @c_BUSR6_10='', @c_BUSR6_11='', @c_BUSR6_12=''    
   SELECT @c_BUSR6_13='', @c_BUSR6_14='', @c_BUSR6_15='', @c_BUSR6_16=''    
   SELECT @c_BUSR6_17='', @c_BUSR6_18='', @c_BUSR6_19='', @c_BUSR6_20=''    
   SELECT @c_BUSR6_21='', @c_BUSR6_22='', @c_BUSR6_23='', @c_BUSR6_24=''    
   SELECT @c_BUSR6_25='', @c_BUSR6_26='', @c_BUSR6_27='', @c_BUSR6_28=''    
   SELECT @c_BUSR6_29='', @c_BUSR6_30='', @c_BUSR6_31='', @c_BUSR6_32=''    
    
   --SELECT DISTINCT OrderKey    
   --INTO #TempOrder    
   --FROM  PACKHEADER (NOLOCK)    
   --WHERE PACKHEADER.pickslipno = @c_Pickslipno    
    
   select DISTINCT d.orderkey     
   INTO #TempOrder    
   FROM Packdetail (nolock) a    
   JOIN Packheader (nolock) b on a.pickslipno = b.pickslipno    
   JOIN pickheader (nolock) c on b.pickslipno = c.pickheaderkey    
   JOIN Orders (nolock) d on c.Orderkey = d.Orderkey    
   WHERE b.pickslipno = @c_Pickslipno    
    
 --SELECT DISTINCT @c_ODLoadkey = orderdetail.loadkey    
 --FROM orderdetail(NOLOCK)     
 --JOIN packheader(NOLOCK) ON PackHeader.OrderKey = ORDERDETAIL.OrderKey    
 --WHERE packheader.pickslipno = @c_Pickslipno    
    
   select DISTINCT  @c_ODLoadkey = b.LoadKey    
   FROM Packdetail (nolock) a    
   JOIN Packheader (nolock) b on a.pickslipno = b.pickslipno    
   JOIN pickheader (nolock) c on b.pickslipno = c.pickheaderkey    
   JOIN Orders (nolock) d on c.Orderkey = d.Orderkey    
   WHERE b.pickslipno = @c_Pickslipno    
    
   WHILE (1=1)    
   BEGIN    
      SELECT @c_TempOrderKey = MIN(OrderKey)    
      FROM #TempOrder    
      WHERE OrderKey > @c_TempOrderKey    
    
      IF @c_TempOrderKey IS NULL OR @c_TempOrderKey = ''  BREAK    
    
      -- Get all unique sizes for the same order and same floor    
      DECLARE pick_cur CURSOR FAST_FORWARD READ_ONLY FOR    
      SELECT dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(OD.Sku)), 10, 5)) SSize,        
             OD.Orderkey    
              ,'' BUSR6 --,SKU.BUSR6 BUSR6    
--            ,substring(sku.busr10,1,10)    
              ,CASE WHEN ISNUMERIC(C.short) = 1 THEN CAST(CAST(C.Short AS FLOAT) AS NVARCHAR(10)) ELSE C.Short END      
      FROM ORDERDETAIL OD (NOLOCK)    
      JOIN LOADPLANDETAIL LP (NOLOCK) ON (LP.Orderkey= OD.Orderkey)    
      JOIN SKU (NOLOCK) ON (SKU.SKU = OD.SKU AND SKU.Storerkey = OD.Storerkey)    
      LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'SIZELSTORD' AND C.storerkey = OD.storerkey    
                                     AND C.code = dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(OD.Sku)), 10, 5))    
      WHERE OD.OrderKey = @c_TempOrderKey    
        AND OD.Loadkey = @c_ODLoadkey    
      GROUP BY dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(OD.sku)), 10, 5)),             
             OD.OrderKey --,BUSR6 --,substring(sku.busr10,1,10)                                 
             ,CASE WHEN ISNUMERIC(C.short) = 1 THEN CAST(CAST(C.Short AS FLOAT) AS NVARCHAR(10)) ELSE C.Short END     
      ORDER BY OD.OrderKey, --BUSR6, --substring(sku.busr10,1,10),                                
               --SSize                                                                         
               CASE WHEN ISNUMERIC(C.short) = 1 THEN CAST(CAST(C.Short AS FLOAT) AS NVARCHAR(10)) ELSE C.Short END     
             --isnumeric(dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(OD.Sku)), 10, 5))) desc,                                                                        
             --CASE WHEN isnumeric(dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(OD.Sku)), 10, 5))) = 1 THEN CAST(dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(OD.sku)), 10, 5)) as numeric)    
             --     ELSE LEN(dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(OD.Sku)), 10, 5)) )    
    
      OPEN pick_cur    
      FETCH NEXT FROM pick_cur INTO @c_SkuSize, @c_OrderKey ,@C_BUSR6,@c_size --,@C_BUSR10--, @c_Floor       
    
      WHILE (@@FETCH_STATUS <> -1)    
      BEGIN    
    
    
         SELECT @n_Count = @n_Count + 1    
         IF @b_debug = 1    
         BEGIN    
            SELECT 'Count of sizes is ' + CONVERT(NVARCHAR(5), @n_Count)    
         END    
    
         SELECT @c_SkuSize1 =  CASE @n_Count WHEN 1    
                               THEN @c_SkuSize    
                               ELSE @c_SkuSize1    
                               END    
         SELECT @c_SkuSize2 =  CASE @n_Count WHEN 2    
                               THEN @c_SkuSize    
                               ELSE @c_SkuSize2    
                               END    
         SELECT @c_SkuSize3 =  CASE @n_Count WHEN 3    
                               THEN @c_SkuSize    
                               ELSE @c_SkuSize3    
                               END    
         SELECT @c_SkuSize4 =  CASE @n_Count WHEN 4    
                               THEN @c_SkuSize    
                               ELSE @c_SkuSize4    
                               END    
         SELECT @c_SkuSize5 =  CASE @n_Count WHEN 5    
                               THEN @c_SkuSize    
                               ELSE @c_SkuSize5    
                               END    
         SELECT @c_SkuSize6 =  CASE @n_Count WHEN 6    
                               THEN @c_SkuSize    
                               ELSE @c_SkuSize6    
                               END    
         SELECT @c_SkuSize7 =  CASE @n_Count WHEN 7    
                               THEN @c_SkuSize    
                               ELSE @c_SkuSize7    
                               END    
         SELECT @c_SkuSize8 =  CASE @n_Count WHEN 8    
                               THEN @c_SkuSize    
                               ELSE @c_SkuSize8    
                               END    
         SELECT @c_SkuSize9 =  CASE @n_Count WHEN 9    
                               THEN @c_SkuSize    
                               ELSE @c_SkuSize9    
                               END    
         SELECT @c_SkuSize10 = CASE @n_Count WHEN 10    
                               THEN @c_SkuSize    
                    ELSE @c_SkuSize10    
                               END    
         SELECT @c_SkuSize11 = CASE @n_Count WHEN 11    
                               THEN @c_SkuSize    
                               ELSE @c_SkuSize11    
                               END    
         SELECT @c_SkuSize12 = CASE @n_Count WHEN 12    
                               THEN @c_SkuSize    
                               ELSE @c_SkuSize12    
                               END    
         SELECT @c_SkuSize13 = CASE @n_Count WHEN 13    
                               THEN @c_SkuSize    
                               ELSE @c_SkuSize13    
                               END    
         SELECT @c_SkuSize14 = CASE @n_Count WHEN 14    
                               THEN @c_SkuSize    
                               ELSE @c_SkuSize14    
                               END    
         SELECT @c_SkuSize15 = CASE @n_Count WHEN 15    
                               THEN @c_SkuSize    
                               ELSE @c_SkuSize15    
                               END    
         SELECT @c_SkuSize16 = CASE @n_Count WHEN 16    
                               THEN @c_SkuSize    
                               ELSE @c_SkuSize16    
                               END    
         SELECT @c_SkuSize17 = CASE @n_Count WHEN 17    
                               THEN @c_SkuSize    
                               ELSE @c_SkuSize17    
                               END    
         SELECT @c_SkuSize18 = CASE @n_Count WHEN 18    
                               THEN @c_SkuSize    
                               ELSE @c_SkuSize18    
                               END    
         SELECT @c_SkuSize19 = CASE @n_Count WHEN 19    
                               THEN @c_SkuSize    
                               ELSE @c_SkuSize19    
                               END    
         SELECT @c_SkuSize20 = CASE @n_Count WHEN 20    
                               THEN @c_SkuSize    
                               ELSE @c_SkuSize20    
                               END    
         SELECT @c_SkuSize21 = CASE @n_Count WHEN 21    
                               THEN @c_SkuSize    
                               ELSE @c_SkuSize21    
                               END    
         SELECT @c_SkuSize22 = CASE @n_Count WHEN 22    
                               THEN @c_SkuSize    
                               ELSE @c_SkuSize22    
                               END    
         SELECT @c_SkuSize23 = CASE @n_Count WHEN 23    
                               THEN @c_SkuSize    
                               ELSE @c_SkuSize23    
                               END    
         SELECT @c_SkuSize24 = CASE @n_Count WHEN 24    
                               THEN @c_SkuSize    
                               ELSE @c_SkuSize24    
                               END    
         SELECT @c_SkuSize25 = CASE @n_Count WHEN 25    
                               THEN @c_SkuSize    
                               ELSE @c_SkuSize25    
                               END    
         SELECT @c_SkuSize26 = CASE @n_Count WHEN 26    
                               THEN @c_SkuSize    
                               ELSE @c_SkuSize26    
                               END    
         SELECT @c_SkuSize27 = CASE @n_Count WHEN 27    
                               THEN @c_SkuSize    
                               ELSE @c_SkuSize27    
                               END    
         SELECT @c_SkuSize28 = CASE @n_Count WHEN 28    
                               THEN @c_SkuSize    
                               ELSE @c_SkuSize28    
                               END    
         SELECT @c_SkuSize29 = CASE @n_Count WHEN 29    
                               THEN @c_SkuSize    
                               ELSE @c_SkuSize29    
                               END    
         SELECT @c_SkuSize30 = CASE @n_Count WHEN 30    
                               THEN @c_SkuSize    
                               ELSE @c_SkuSize30    
                               END    
         SELECT @c_SkuSize31 = CASE @n_Count WHEN 31    
                               THEN @c_SkuSize    
                               ELSE @c_SkuSize31    
                               END    
         SELECT @c_SkuSize32 = CASE @n_Count WHEN 32    
                               THEN @c_SkuSize    
                               ELSE @c_SkuSize32    
                               END    
             
    
         SELECT @c_SkuSize33 = CASE @n_Count WHEN 33    
                               THEN @c_SkuSize    
                               ELSE @c_SkuSize33    
                               END    
         SELECT @c_SkuSize34 = CASE @n_Count WHEN 34    
                               THEN @c_SkuSize    
                               ELSE @c_SkuSize34    
                               END    
    
            SELECT @c_SkuSize35 = CASE @n_Count WHEN 35    
                               THEN @c_SkuSize    
                               ELSE @c_SkuSize35    
                               END    
         SELECT @c_SkuSize36 = CASE @n_Count WHEN 36    
                               THEN @c_SkuSize    
                               ELSE @c_SkuSize36    
                               END    
    
         IF @n_Count > 36    
         BEGIN    
           SET @c_MoreField = 'More Fields'    
         END    
    
             
    
         -- SOS41626 To get BUSR6 for individual size    
       -- WMS-7680 CS01-- remove --start    
      /* SELECT @c_BUSR6_01 = CASE @n_Count WHEN 1    
                               THEN @c_BUSR6    
                               ELSE @c_BUSR6_01    
                               END    
         SELECT @c_BUSR6_02 = CASE @n_Count WHEN 2    
                               THEN @c_BUSR6    
                               ELSE @c_BUSR6_02    
                               END    
         SELECT @c_BUSR6_03 = CASE @n_Count WHEN 3    
                               THEN @c_BUSR6    
                               ELSE @c_BUSR6_03    
                               END    
         SELECT @c_BUSR6_04 = CASE @n_Count WHEN 4    
                               THEN @c_BUSR6    
                               ELSE @c_BUSR6_04    
                               END    
         SELECT @c_BUSR6_05 = CASE @n_Count WHEN 5    
                               THEN @c_BUSR6    
                               ELSE @c_BUSR6_05    
                               END    
         SELECT @c_BUSR6_06 = CASE @n_Count WHEN 6    
                               THEN @c_BUSR6    
                               ELSE @c_BUSR6_06    
                               END    
         SELECT @c_BUSR6_07 = CASE @n_Count WHEN 7    
                               THEN @c_BUSR6    
                               ELSE @c_BUSR6_07    
                               END    
         SELECT @c_BUSR6_08 = CASE @n_Count WHEN 8    
                               THEN @c_BUSR6    
                               ELSE @c_BUSR6_08    
                               END    
         SELECT @c_BUSR6_09 = CASE @n_Count WHEN 9    
                               THEN @c_BUSR6    
                               ELSE @c_BUSR6_09    
                               END    
         SELECT @c_BUSR6_10 = CASE @n_Count WHEN 10    
                               THEN @c_BUSR6    
                               ELSE @c_BUSR6_10    
                   END    
         SELECT @c_BUSR6_11 = CASE @n_Count WHEN 11    
                               THEN @c_BUSR6    
                               ELSE @c_BUSR6_11    
                               END    
         SELECT @c_BUSR6_12 = CASE @n_Count WHEN 12    
                               THEN @c_BUSR6    
                               ELSE @c_BUSR6_12    
                               END    
         SELECT @c_BUSR6_13 = CASE @n_Count WHEN 13    
                               THEN @c_BUSR6    
                               ELSE @c_BUSR6_13    
                               END    
         SELECT @c_BUSR6_14 = CASE @n_Count WHEN 14    
                               THEN @c_BUSR6    
                               ELSE @c_BUSR6_14    
                               END    
         SELECT @c_BUSR6_15 = CASE @n_Count WHEN 15    
                               THEN @c_BUSR6    
                               ELSE @c_BUSR6_15    
                               END    
         SELECT @c_BUSR6_16 = CASE @n_Count WHEN 16                                 THEN @c_BUSR6    
                               ELSE @c_BUSR6_16    
                               END    
         SELECT @c_BUSR6_17 = CASE @n_Count WHEN 17    
                               THEN @c_BUSR6    
                               ELSE @c_BUSR6_17    
                               END    
         SELECT @c_BUSR6_18 = CASE @n_Count WHEN 18    
                               THEN @c_BUSR6    
                               ELSE @c_BUSR6_18    
                               END    
         SELECT @c_BUSR6_19 = CASE @n_Count WHEN 19    
                               THEN @c_BUSR6    
                               ELSE @c_BUSR6_19    
                               END    
         SELECT @c_BUSR6_20 = CASE @n_Count WHEN 20    
                               THEN @c_BUSR6    
                               ELSE @c_BUSR6_20    
                               END    
         SELECT @c_BUSR6_21 = CASE @n_Count WHEN 21    
                               THEN @c_BUSR6    
                               ELSE @c_BUSR6_21    
                               END    
         SELECT @c_BUSR6_22 = CASE @n_Count WHEN 22    
                               THEN @c_BUSR6    
                               ELSE @c_BUSR6_22    
                               END    
         SELECT @c_BUSR6_23 = CASE @n_Count WHEN 23    
                               THEN @c_BUSR6    
                               ELSE @c_BUSR6_23    
                               END    
         SELECT @c_BUSR6_24 = CASE @n_Count WHEN 24    
                               THEN @c_BUSR6    
                               ELSE @c_BUSR6_24    
                               END    
         SELECT @c_BUSR6_25 = CASE @n_Count WHEN 25    
                               THEN @c_BUSR6    
                               ELSE @c_BUSR6_25    
                               END    
         SELECT @c_BUSR6_26 = CASE @n_Count WHEN 26    
                               THEN @c_BUSR6    
                               ELSE @c_BUSR6_26    
                               END    
         SELECT @c_BUSR6_27 = CASE @n_Count WHEN 27    
                               THEN @c_BUSR6    
                               ELSE @c_BUSR6_27    
                               END    
         SELECT @c_BUSR6_28 = CASE @n_Count WHEN 28    
                               THEN @c_BUSR6    
                               ELSE @c_BUSR6_28    
                               END    
         SELECT @c_BUSR6_29 = CASE @n_Count WHEN 29    
                               THEN @c_BUSR6    
                               ELSE @c_BUSR6_29    
                               END    
         SELECT @c_BUSR6_30 = CASE @n_Count WHEN 30    
                               THEN @c_BUSR6    
                               ELSE @c_BUSR6_30    
                               END    
         SELECT @c_BUSR6_31 = CASE @n_Count WHEN 31    
                               THEN @c_BUSR6    
                               ELSE @c_BUSR6_31    
                               END    
         SELECT @c_BUSR6_32 = CASE @n_Count WHEN 32    
                               THEN @c_BUSR6    
                               ELSE @c_BUSR6_32    
                               END    
          End    
         */    
    
         IF @b_debug = 1    
         BEGIN    
         if @c_TempOrderKey = '0000907514' -- checking any orderkey    
            BEGIN    
               SELECT 'SkuSize is ' + @c_SkuSize    
               SELECT 'SkuSize1 to 16 is ' + @c_SkuSize1+','+ @c_SkuSize2+','+ @c_SkuSize3+','+ @c_SkuSize4+','+    
                                      @c_SkuSize5+','+ @c_SkuSize6+','+ @c_SkuSize7+','+ @c_SkuSize8+','+    
                                      @c_SkuSize9+','+ @c_SkuSize10+','+ @c_SkuSize11+','+ @c_SkuSize12+','+    
                                      @c_SkuSize13+','+ @c_SkuSize14+','+ @c_SkuSize15+','+ @c_SkuSize16+','+    
                                    -- SOS29528    
                                      @c_SkuSize17+','+ @c_SkuSize18+','+ @c_SkuSize19+','+ @c_SkuSize20+','+    
                                      @c_SkuSize21+','+ @c_SkuSize22+','+ @c_SkuSize23+','+ @c_SkuSize24+','+    
                                     @c_SkuSize25+','+ @c_SkuSize26+','+ @c_SkuSize27+','+ @c_SkuSize28+','+    
                                      @c_SkuSize29+','+ @c_SkuSize30+','+ @c_SkuSize31+','+ @c_SkuSize32    
               -- SOS41626    
               SELECT 'BUSR6_01 to 32 is ' + @c_BUSR6_01+','+ @c_BUSR6_02+','+ @c_BUSR6_03+','+ @c_BUSR6_04+','+    
                                  @c_BUSR6_05+','+ @c_BUSR6_06+','+ @c_BUSR6_07+','+ @c_BUSR6_08+','+    
                                  @c_BUSR6_09+','+ @c_BUSR6_10+','+ @c_BUSR6_11+','+ @c_BUSR6_12+','+    
                                  @c_BUSR6_13+','+ @c_BUSR6_14+','+ @c_BUSR6_15+','+ @c_BUSR6_16+','+    
                                  @c_BUSR6_17+','+ @c_BUSR6_18+','+ @c_BUSR6_19+','+ @c_BUSR6_20+','+    
                                             @c_BUSR6_21+','+ @c_BUSR6_22+','+ @c_BUSR6_23+','+ @c_BUSR6_24+','+    
                                  @c_BUSR6_25+','+ @c_BUSR6_26+','+ @c_BUSR6_27+','+ @c_BUSR6_28+','+    
                                  @c_BUSR6_29+','+ @c_BUSR6_30+','+ @c_BUSR6_31+','+ @c_BUSR6_32    
            END    
         END    
    
         SELECT @c_PrevOrderKey = @c_OrderKey    
    
         FETCH NEXT FROM pick_cur INTO @c_SkuSize, @c_OrderKey ,@C_BUSR6,@c_size --,@C_BUSR10    
    
         IF @b_debug = 1    
         BEGIN    
            SELECT 'PrevOrderkey= ' + @c_PrevOrderKey + ', Orderkey= ' + @c_OrderKey    
         END    
    
    
         IF (@c_PrevOrderKey <> @c_OrderKey) OR    
            (@@FETCH_STATUS = -1) -- last fetch    
         BEGIN    
            -- Insert into temp table    
            INSERT INTO #TempPickSlip    
            SELECT  Pickheader.Pickheaderkey,    
                  LOADPLANDETAIL.Loadkey,    
                  ORDERS.Orderkey,    
                  ORDERS.ExternOrderKey,    
                  ORDERS.ExternPOkey,    
                  CONVERT(nvarchar(255), ORDERS.Notes) Notes,    
                  ORDERS.ConsigneeKey,    
                  ORDERS.C_Company,    
                  ORDERS.c_Address1,    
                  ORDERS.c_Address2,    
                  ORDERS.c_Address3,    
                  ORDERS.c_City,    
                  ORDERS.c_Zip,    
                  ORDERS.Userdefine06,    
                  ORDERS.Type,    
                  --Codelkup.long,                                 
                  Long = (SELECT TOP 1 CODELKUP.DESCRIPTION    
                           FROM CODELKUP (NOLOCK)    
                           WHERE LISTNAME = 'ORDERTYPE'    
                           AND CODELKUP.CODE = ORDERS.TYPE    
                           AND (CODELKUP.STORERKEY = ORDERS.STORERKEY    
                                 OR ISNULL(CODELKUP.STORERKEY,'') = '')    
                           ORDER BY CODELKUP.STORERKEY DESC),      
                  SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(OD.Sku)), 1, 9) StyleColour,    
                  PACK.PackUom3 UOM,    
                  PACK.CaseCnt,    
                  --"0" TotCarton, --CEILING(CONVERT(DECIMAL(8,2), SUM((OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) / PACK.CaseCnt))) TotCarton,    
                  --SUM(PACKHEADER.TTLCNTS) AS TotCarton,    
                  (SELECT SUM(PACKHEADER.TTLCNTS) FROM PACKHEADER(NOLOCK) WHERE PICKSLIPNO =  @c_Pickslipno),  
                  @c_SkuSize1,    
                  @c_SkuSize2,    
                  @c_SkuSize3,    
                  @c_SkuSize4,    
                  @c_SkuSize5,    
                  @c_SkuSize6,    
                  @c_SkuSize7,    
                  @c_SkuSize8,    
                  @c_SkuSize9,    
                  @c_SkuSize10,    
                  @c_SkuSize11,    
                  @c_SkuSize12,    
                  @c_SkuSize13,    
                  @c_SkuSize14,    
                  @c_SkuSize15,    
                  @c_SkuSize16,    
                  @c_SkuSize17,    
                  @c_SkuSize18,    
                  @c_SkuSize19,    
                  @c_SkuSize20,    
                  @c_SkuSize21,    
                  @c_SkuSize22,    
                  @c_SkuSize23,    
                  @c_SkuSize24,    
                  @c_SkuSize25,    
                  @c_SkuSize26,    
                  @c_SkuSize27,    
                  @c_SkuSize28,    
                  @c_SkuSize29,    
                  @c_SkuSize30,    
                  @c_SkuSize31,    
                  @c_SkuSize32,                           
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(OD.Sku)), 10, 5)) = @c_SkuSize1 --AND SKU.BUSR6 = @c_BUSR6_01          
                        THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)   
                        ELSE 0    
                        END,    
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(OD.Sku)), 10, 5)) = @c_SkuSize2 --AND SKU.BUSR6 = @c_BUSR6_02    
                        THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)   
                        ELSE 0    
                        END,    
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(OD.Sku)), 10, 5)) = @c_SkuSize3 --AND SKU.BUSR6 = @c_BUSR6_03    
                        THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)   
                        ELSE 0    
                        END,    
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(OD.Sku)), 10, 5)) = @c_SkuSize4 --AND SKU.BUSR6 = @c_BUSR6_04    
        THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)   
                        ELSE 0    
                        END,    
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(OD.Sku)), 10, 5)) = @c_SkuSize5 --AND SKU.BUSR6 = @c_BUSR6_05    
                        THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)   
                        ELSE 0    
                        END,    
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(OD.Sku)), 10, 5)) = @c_SkuSize6 --AND SKU.BUSR6 = @c_BUSR6_06    
                        THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)   
                        ELSE 0    
                        END,    
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(OD.Sku)), 10, 5)) = @c_SkuSize7 --AND SKU.BUSR6 = @c_BUSR6_07    
                        THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)   
                        ELSE 0    
                        END,    
        CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(OD.Sku)), 10, 5)) = @c_SkuSize8 --AND SKU.BUSR6 = @c_BUSR6_08    
                        THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)   
                        ELSE 0    
                        END,    
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(OD.Sku)), 10, 5)) = @c_SkuSize9 --AND SKU.BUSR6 = @c_BUSR6_09    
                        THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)   
                        ELSE 0    
                        END,    
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(OD.Sku)), 10, 5)) = @c_SkuSize10 --AND SKU.BUSR6 = @c_BUSR6_10    
                        THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)   
                        ELSE 0    
                        END,    
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(OD.Sku)), 10, 5)) = @c_SkuSize11 --AND SKU.BUSR6 = @c_BUSR6_11    
                        THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)   
                        ELSE 0    
                        END,    
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(OD.Sku)), 10, 5)) = @c_SkuSize12 --AND SKU.BUSR6 = @c_BUSR6_12    
                        THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)   
                        ELSE 0    
                        END,    
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(OD.Sku)), 10, 5)) = @c_SkuSize13 --AND SKU.BUSR6 = @c_BUSR6_13    
                        THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)   
                        ELSE 0    
                        END,    
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(OD.Sku)), 10, 5)) = @c_SkuSize14 --AND SKU.BUSR6 = @c_BUSR6_14    
                        THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)   
                        ELSE 0    
                        END,    
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(OD.Sku)), 10, 5)) = @c_SkuSize15 --AND SKU.BUSR6 = @c_BUSR6_15    
                        THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)   
                        ELSE 0    
                        END,    
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(OD.Sku)), 10, 5)) = @c_SkuSize16 --AND SKU.BUSR6 = @c_BUSR6_16    
                        THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)   
                        ELSE 0    
                        END,    
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(OD.Sku)), 10, 5)) = @c_SkuSize17 --AND SKU.BUSR6 = @c_BUSR6_17    
                        THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)   
                        ELSE 0    
                        END,    
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(OD.Sku)), 10, 5)) = @c_SkuSize18 --AND SKU.BUSR6 = @c_BUSR6_18    
                        THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)   
                        ELSE 0    
                        END,    
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(OD.Sku)), 10, 5)) = @c_SkuSize19 --AND SKU.BUSR6 = @c_BUSR6_19    
                        THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)   
                        ELSE 0    
                        END,    
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(OD.Sku)), 10, 5)) = @c_SkuSize20 --AND SKU.BUSR6 = @c_BUSR6_20    
                     THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)   
                        ELSE 0    
                        END,    
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(OD.Sku)), 10, 5)) = @c_SkuSize21 --AND SKU.BUSR6 = @c_BUSR6_21    
                        THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)   
                        ELSE 0    
                        END,    
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(OD.Sku)), 10, 5)) = @c_SkuSize22 --AND SKU.BUSR6 = @c_BUSR6_22    
                        THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)   
                        ELSE 0    
                        END,    
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(OD.Sku)), 10, 5)) = @c_SkuSize23 --AND SKU.BUSR6 = @c_BUSR6_23    
                        THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)   
                        ELSE 0    
                        END,    
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(OD.Sku)), 10, 5)) = @c_SkuSize24 --AND SKU.BUSR6 = @c_BUSR6_24    
                        THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)   
                        ELSE 0    
                        END,    
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(OD.Sku)), 10, 5)) = @c_SkuSize25 --AND SKU.BUSR6 = @c_BUSR6_25    
                        THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)   
                        ELSE 0    
                        END,    
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(OD.Sku)), 10, 5)) = @c_SkuSize26 --AND SKU.BUSR6 = @c_BUSR6_26    
                        THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)   
                        ELSE 0    
                        END,    
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(OD.Sku)), 10, 5)) = @c_SkuSize27 --AND SKU.BUSR6 = @c_BUSR6_27    
                        THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)   
                        ELSE 0    
                        END,    
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(OD.Sku)), 10, 5)) = @c_SkuSize28 --AND SKU.BUSR6 = @c_BUSR6_28    
                        THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)   
                        ELSE 0    
                        END,    
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(OD.Sku)), 10, 5)) = @c_SkuSize29 --AND SKU.BUSR6 = @c_BUSR6_29    
                        THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)   
                        ELSE 0    
                        END,    
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(OD.Sku)), 10, 5)) = @c_SkuSize30 --AND SKU.BUSR6 = @c_BUSR6_30    
                        THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)   
                        ELSE 0    
                        END,    
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(OD.Sku)), 10, 5)) = @c_SkuSize31 --AND SKU.BUSR6 = @c_BUSR6_31    
                        THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)   
                        ELSE 0    
                        END,    
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(OD.Sku)), 10, 5)) = @c_SkuSize32 --AND SKU.BUSR6 = @c_BUSR6_32        End    
                        THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)   
                        ELSE 0    
                        END,    
                  STORER.Address1,    
                  STORER.Address2,    
                  STORER.Phone1,    
                  STORER.Company,    
                 @c_SkuSize33,    
                 @c_SkuSize34,    
                 @c_SkuSize35,    
                 @c_SkuSize36,    
                 CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(OD.Sku)), 10, 5)) = @c_SkuSize33    
                        THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)   
                        ELSE 0    
                        END,    
                 CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(OD.Sku)), 10, 5)) = @c_SkuSize34    
                        THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)   
                        ELSE 0    
                        END,    
                 CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(OD.Sku)), 10, 5)) = @c_SkuSize35    
                        THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)   
                  ELSE 0    
                        END,    
                CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(OD.Sku)), 10, 5)) = @c_SkuSize36    
                        THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)   
                        ELSE 0    
                        END    
                ,@c_MoreField    
      ,ISNULL(ORDERS.B_Company,'')      --ML01      
      ,(SELECT TOP 1 PD.DropID FROM Packdetail (NOLOCK) PD     
        JOIN Packheader (nolock) PH on PD.Pickslipno = PH.Pickslipno     
      WHERE PD.CartonNo = PH.TTLCNTS AND pd.PickSlipNo = @c_Pickslipno)    
            FROM ORDERDETAIL OD (NOLOCK)    
            JOIN ORDERS (NOLOCK) ON OD.OrderKey = ORDERS.OrderKey    
            JOIN PACK (NOLOCK) ON OD.Packkey = PACK.Packkey    
            JOIN LOADPLANDETAIL (NOLOCK) ON OD.OrderKey = LOADPLANDETAIL.OrderKey AND    
                                            LOADPLANDETAIL.Loadkey = ORDERS.Loadkey    
            JOIN SKU (NOLOCK) ON (SKU.StorerKey = OD.StorerKey AND    
                                  SKU.SKU = OD.SKU)    
            LEFT JOIN PICKHEADER (NOLOCK) ON (OD.OrderKey = Pickheader.orderkey)    
            --LEFT JOIN CODELKUP (NOLOCK) ON (CODELKUP.Code = ORDERS.Type AND ListName='ORDERTYPE')     
            JOIN STORER (NOLOCK) ON (ORDERS.Storerkey = STORER.Storerkey)    
            --JOIN PACKHEADER(NOLOCK) ON PackHeader.OrderKey = LoadPlanDetail.OrderKey    
            --JOIN PACKDETAIL(NOLOCK) ON PackDetail.PickSlipNo = PackHeader.PickSlipNo AND PackDetail.SKU = SKU.Sku    
            WHERE ORDERS.OrderKey = @c_PrevOrderKey    
            AND PACK.CaseCnt > 0    
            AND 1 = CASE dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(OD.Sku)), 10, 5))    
                                                                           WHEN @c_SkuSize1        
                                                                                          THEN 1    
                                                                           WHEN @c_SkuSize2    
                                                                                          THEN 1    
                                                                           WHEN @c_SkuSize3    
                                                                                          THEN 1    
                                                                           WHEN @c_SkuSize4    
                                                                                          THEN 1    
                                                                           WHEN @c_SkuSize5    
                                                                                          THEN 1    
                                                                           WHEN @c_SkuSize6    
                                                                                          THEN 1    
                                                                           WHEN @c_SkuSize7    
                                                                                          THEN 1    
                                                                           WHEN @c_SkuSize8    
                                                                                          THEN 1    
                                                                           WHEN @c_SkuSize9    
                                                                                          THEN 1    
                                                                           WHEN @c_SkuSize10    
                                                                                          THEN 1    
                                                                           WHEN @c_SkuSize11    
                                                                                          THEN 1    
                                                                           WHEN @c_SkuSize12    
                                                                                          THEN 1    
                                                                           WHEN @c_SkuSize13    
                                                                                          THEN 1    
                                                                           WHEN @c_SkuSize14    
                                                                                          THEN 1    
                                                                           WHEN @c_SkuSize15    
                                                                                          THEN 1    
                                                                           WHEN @c_SkuSize16    
                                                                                          THEN 1    
                                                                           WHEN @c_SkuSize17    
                                                                                          THEN 1    
                                                                           WHEN @c_SkuSize18    
                                                                                          THEN 1    
                                                                           WHEN @c_SkuSize19    
                                                                                          THEN 1    
                                                                           WHEN @c_SkuSize20    
                                                                                          THEN 1    
                                                                           WHEN @c_SkuSize21    
                                                                                          THEN 1    
                                                                           WHEN @c_SkuSize22    
                                                                                          THEN 1    
                                                                           WHEN @c_SkuSize23    
                                                                                          THEN 1    
                                                                           WHEN @c_SkuSize24    
                                                                                          THEN 1    
                                                                           WHEN @c_SkuSize25    
                                                                                          THEN 1    
                                                                           WHEN @c_SkuSize26    
                                                                                          THEN 1    
                                                                           WHEN @c_SkuSize27    
                                                                                          THEN 1    
                                                                           WHEN @c_SkuSize28    
                                                                                          THEN 1    
                                                                           WHEN @c_SkuSize29    
                                                                                          THEN 1    
                                                                           WHEN @c_SkuSize30    
                                                                                          THEN 1    
                                                                           WHEN @c_SkuSize31    
                                                                                          THEN 1    
                                                                           WHEN @c_SkuSize32    
                                                                                          THEN 1    
                                                                           WHEN @c_SkuSize33    
                                                                                          THEN 1    
                                                                           WHEN @c_SkuSize34    
                                                                                          THEN 1    
                                                                           WHEN @c_SkuSize35    
                                                                                          THEN 1    
                                                                           WHEN @c_SkuSize36    
                                                                                          THEN 1    
                                                                           ELSE 0    
                                                                           END    
            GROUP BY Pickheader.Pickheaderkey,    
                     LOADPLANDETAIL.Loadkey,    
                     ORDERS.Orderkey,    
                     ORDERS.ExternOrderKey,    
                     ORDERS.ExternPOkey,    
                     CONVERT(nvarchar(255), ORDERS.Notes),    
                     ORDERS.ConsigneeKey,    
                     ORDERS.C_Company,    
                     ORDERS.c_Address1,    
                     ORDERS.c_Address2,    
                     ORDERS.c_Address3,    
                     ORDERS.c_City,    
                     ORDERS.c_Zip,    
                     ORDERS.Userdefine06,    
                     ORDERS.Type,    
                     --Codelkup.long,      
                     ORDERS.TYPE,          
                     ORDERS.STORERKEY,     
                     SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(OD.Sku)), 1, 9),    
                     dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(OD.Sku)), 10, 5)),       
                     PACK.PackUom3,    
                     PACK.CaseCnt,    
                  -- SOS41626    
                    SKU.BUSR6,    
                    STORER.Address1,    
                    STORER.Address2,    
                    STORER.Phone1,    
                    STORER.Company    
                    ,ISNULL(ORDERS.B_Company,'')      --ML01     
                    --,PACKDETAIL.QTY      
                    --,PACKDETAIL.Dropid    
            HAVING SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) > 0    
            ORDER BY ORDERS.OrderKey,    
                    StyleColour,    
                    UOM    
    
            -- Reset counter and skusize    
            SELECT @n_Count = 0    
            SELECT @c_SkuSize1='',  @c_SkuSize2='',  @c_SkuSize3='',  @c_SkuSize4=''    
            SELECT @c_SkuSize5='',  @c_SkuSize6='',  @c_SkuSize7='',  @c_SkuSize8=''    
            SELECT @c_SkuSize9='',  @c_SkuSize10='', @c_SkuSize11='', @c_SkuSize12=''    
            SELECT @c_SkuSize13='', @c_SkuSize14='', @c_SkuSize15='', @c_SkuSize16=''    
            SELECT @c_SkuSize17='', @c_SkuSize18='', @c_SkuSize19='', @c_SkuSize20=''    
            SELECT @c_SkuSize21='', @c_SkuSize22='', @c_SkuSize23='', @c_SkuSize24=''    
            SELECT @c_SkuSize25='', @c_SkuSize26='', @c_SkuSize27='', @c_SkuSize28=''    
            SELECT @c_SkuSize29='', @c_SkuSize30='', @c_SkuSize31='', @c_SkuSize32=''    
    
            SELECT @c_SkuSize33='', @c_SkuSize34='', @c_SkuSize35='', @c_SkuSize36=''        
    
            SELECT @c_BUSR6_01='', @c_BUSR6_02='', @c_BUSR6_03='', @c_BUSR6_04=''    
            SELECT @c_BUSR6_05='', @c_BUSR6_06='', @c_BUSR6_07='', @c_BUSR6_08=''    
            SELECT @c_BUSR6_09='', @c_BUSR6_10='', @c_BUSR6_11='', @c_BUSR6_12=''    
            SELECT @c_BUSR6_13='', @c_BUSR6_14='', @c_BUSR6_15='', @c_BUSR6_16=''    
            SELECT @c_BUSR6_17='', @c_BUSR6_18='', @c_BUSR6_19='', @c_BUSR6_20=''    
            SELECT @c_BUSR6_21='', @c_BUSR6_22='', @c_BUSR6_23='', @c_BUSR6_24=''    
            SELECT @c_BUSR6_25='', @c_BUSR6_26='', @c_BUSR6_27='', @c_BUSR6_28=''    
            SELECT @c_BUSR6_29='', @c_BUSR6_30='', @c_BUSR6_31='', @c_BUSR6_32=''    
    
         END    
      END -- WHILE (@@FETCH_STATUS <> -1)    
    
      CLOSE pick_cur    
      DEALLOCATE pick_cur    
    
   END -- WHILE (1=1)    
    
    
    
   SELECT PickSlipNo, Loadkey, OrderKey, ExternOrderKey, ExternPOkey, Notes,    
         ConsigneeKey, Company, c_Address1, c_Address2,c_Address3, c_City, c_Zip, Userdefine06, Type,    
--         DeliveryDate, Notes2, Loc, Sku, UOM, LFloor, Bin,    
--         CodelkupDesc, Sku, UOM, Qty, CaseCnt, SUM(TotCarton) as TotCarton,    
         CodelkupDesc, Sku, UOM, CaseCnt, TotCarton,    
         SkuSize1, SkuSize2, SkuSize3, SkuSize4, SkuSize5, SkuSize6, SkuSize7, SkuSize8,    
         SkuSize9, SkuSize10, SkuSize11, SkuSize12, SkuSize13, SkuSize14, SkuSize15, SkuSize16,    
         SkuSize17, SkuSize18, SkuSize19, SkuSize20, SkuSize21, SkuSize22, SkuSize23, SkuSize24,    
         SkuSize25, SkuSize26, SkuSize27, SkuSize28, SkuSize29, SkuSize30, SkuSize31, SkuSize32,    
         SUM(Qty1) Qty1, SUM(Qty2) Qty2, SUM(Qty3) Qty3, SUM(Qty4) Qty4, SUM(Qty5) Qty5, SUM(Qty6) Qty6,    
         SUM(Qty7) Qty7, SUM(Qty8) Qty8, SUM(Qty9) Qty9, SUM(Qty10) Qty10, SUM(Qty11) Qty11, SUM(Qty12) Qty12,    
         SUM(Qty13) Qty13, SUM(Qty14) Qty14, SUM(Qty15) Qty15, SUM(Qty16) Qty16,    
         SUM(Qty17) Qty17, SUM(Qty18) Qty18, SUM(Qty19) Qty19, SUM(Qty20) Qty20, SUM(Qty21) Qty21, SUM(Qty22) Qty22,    
         SUM(Qty23) Qty23, SUM(Qty24) Qty24, SUM(Qty25) Qty25, SUM(Qty26) Qty26, SUM(Qty27) Qty27, SUM(Qty28) Qty28,    
         SUM(Qty29) Qty29, SUM(Qty30) Qty30, SUM(Qty31) Qty31, SUM(Qty32) Qty32,    
         StorerAdd1, StorerAdd2, StorerPhone1, StorerCompany, SkuSize33, SkuSize34, SkuSize35, SkuSize36,       
         SUM(Qty33) Qty33, SUM(Qty34) Qty34, SUM(Qty35) Qty35, SUM(Qty36) Qty36,MoreField,B_Company,Dropid             
   FROM #TempPickSlip    
   GROUP BY PickSlipNo, Loadkey, OrderKey, ExternOrderKey, ExternPOkey, Notes,    
            ConsigneeKey, Company, c_Address1, c_Address2, c_Address3, c_City, c_Zip, Userdefine06, Type,    
  --         DeliveryDate, Notes2, Loc, Sku, UOM, LFloor, Bin,    
          CodelkupDesc, Sku, UOM, CaseCnt, TotCarton,    
          SkuSize1, SkuSize2, SkuSize3, SkuSize4, SkuSize5, SkuSize6, SkuSize7, SkuSize8,    
          SkuSize9, SkuSize10, SkuSize11, SkuSize12, SkuSize13, SkuSize14, SkuSize15, SkuSize16,    
          SkuSize17, SkuSize18, SkuSize19, SkuSize20, SkuSize21, SkuSize22, SkuSize23, SkuSize24,    
          SkuSize25, SkuSize26, SkuSize27, SkuSize28, SkuSize29, SkuSize30, SkuSize31, SkuSize32,    
          StorerAdd1, StorerAdd2, StorerPhone1, StorerCompany, SkuSize33, SkuSize34, SkuSize35, SkuSize36,MoreField,B_Company,Dropid             
    
   DROP TABLE #TempOrder    
   DROP TABLE #TempPickSlip    
END   

GO