SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
    
/*************************************************************************************/    
/* Store Procedure: ispNIKEPackingExportList                                         */    
/* Creation Date:                                                                    */    
/* Copyright: IDS                                                                    */    
/* Written by:                                                                       */    
/*                                                                                   */    
/* Purpose:  Loadplan - Print the Nike Packing Export List                           */    
/*                                                                                   */    
/* Input Parameters:  LoadKey                                                        */    
/*                                                                                   */    
/* Called By: Power Builder - r_dw_nike_packing_export_list_01                       */    
/*                                                                                   */    
/* PVCS Version: 1.8                                                                 */    
/*                                                                                   */    
/* Version: 5.4                                                                      */    
/*                                                                                   */    
/* Data Modifications:                                                               */    
/*                                                                                   */    
/* Updates:                                                                          */    
/* Date         Author    Ver Purposes                                               */    
/* 29-Dec-2003  MaryVong      Change ETD & ETA from ORDERS.DeliveryDate to           */    
/*                            POD.InvDespatchDate & MBOL.EditDate                    */    
/*                            - (FBR#18640).                                         */    
/* 06-Jan-2004  MaryVong      Change ETD & ETA from POD.InvDespatchDate &            */    
/*                            MBOL.EditDate to MBOL.EditDate &                       */    
/*                            MBOL.EditDate + LeadTime - (FBR#18640).                */    
/* 09-Dec-2004  June          - (SOS#30230)                                          */    
/* 14-Dec-2004  June          - (SOS#30447)                                          */    
/* 27-Jun-2005  YokeBeen      NSC Project - (SOS#37310) - (YokeBeen01).              */    
/*                            Changed the following..                                */    
/*                            ORDERS.UserDefine04 -> ORDERS.ConsigneeKey             */    
/*                            ORDERS.C_Address1 -> ORDERS.C_Address3 +               */    
/*                            ORDERS.C_Address4 + ORDERS.C_Address2                  */    
/* 19-Jul-2005  YokeBeen      Added join for ORDERDETAIL.SKU =                       */    
/*                            #TEMPRESULT.SKU- (SOS#38261) - (YokeBeen02).           */    
/* 02-Aug-2005  YokeBeen      Changed to extract for ETA calculation based           */    
/*                            on C_City instead of C_Address4                        */    
/*                            - (SOS#38248) - (YokeBeen03).                          */    
/* 31-Oct-2006  MaryVong      SOS61168 Add LabelNo (display as last field            */    
/*                            as per NIKE request)                                   */    
/* 29-Jan-2007  MaryVong      SOS66809 Request to get UPC fron SKU.AltSku            */    
/* 01-Aug-2008  Vanessa   1.1 SOS112598 Request to add         (Vanessa01)           */    
/*                            CAST(CLC.Notes AS NVARCHAR(30)) = Orders.intermodalvehicle */    
/* 19-Sep-2008  TLTING    1.2 Report Report need to convert NVARCHAR()                */    
/*                            Column length need tally with PB (tlting01)            */    
/* 02-Feb-2009  Rick Liew 1.3 Add Orderdetail.UserDefine04 column(SOS127541)         */
/* 14-Jul-2009  NJOW01    1.4 Change City Lead-time measure by hour for air shipment */
/*                            SOS#141844                                             */
/* 04-May-2010  GTGOH     1.5 Add Orders.B_Contact1, Orders.B_Company                */
/*    			               SOS#171031 (GOH01)                                     */
/* 28-Jan-2019  TLTING_ext 1.6  enlarge externorderkey field length                  */
/*************************************************************************************/    
    
CREATE PROC [dbo].[ispNIKEPackingExportList]     
   @c_LoadKey    NVARCHAR(10)    
AS    
BEGIN    
SET NOCOUNT ON   -- SQL 2005 Standard    
SET QUOTED_IDENTIFIER OFF     
SET ANSI_NULLS OFF       
SET CONCAT_NULL_YIELDS_NULL OFF            
    
    
DECLARE @b_debug int    
SELECT  @b_debug = 0    
DECLARE @c_orderkey NVARCHAR(10),    
  @c_orderkey2 NVARCHAR(10), -- SOS30447      
        @c_pickslipno NVARCHAR(10),    
        @c_sku NVARCHAR(20),    
        @c_cartonno int,    
        @c_labelno NVARCHAR(20), -- SOS61168    
        @n_qtypack int,     
        @c_flag NVARCHAR(1),    
        @c_externorderkey NVARCHAR(50),     --tlting_ext  
        @n_orderqty int,     
        @n_remainqtypack int,    
        @n_remainqtyord int,    
        @b_flag1 int,    
        @b_flag2 int ,    
        @n_cnt int,
        @c_userdefine04 NVARCHAR(18) -- SOS 127541     
    
    
   CREATE TABLE #ExpList (    
    PackListNo       NVARCHAR(10) NULL,      
    ExternOrderKey   NVARCHAR(50) NULL,      --tlting_ext
    OrderGroup       NVARCHAR(20) NULL,           
    OrderType        NVARCHAR(250) NULL,     
    BuyerPO          NVARCHAR(20) NULL,     
    WhCode           NVARCHAR(10) NULL,     
    ETD              NVARCHAR(10) NULL,     
    ETA              NVARCHAR(10) NULL,     
    CustomerCode     NVARCHAR(20) NULL,     
    CustomerName     NVARCHAR(30) NULL,     
    CustAddr         NVARCHAR(45) NULL,     
    CartonNo         int,     
    LabelNo          NVARCHAR(20),   -- SOS61168    
    GPC              NVARCHAR(18),    
    Sku              NVARCHAR(20),     
    Style            NVARCHAR(6),     
    Color            NVARCHAR(7),     
    Dimension        NVARCHAR(2),     
    Quality          NVARCHAR(2),     
    UOM              NVARCHAR(2),     
    Size             NVARCHAR(5),     
    UPC              NVARCHAR(30),--ISNULL(MAX(UPC.UPC), '') as UPC,     
    QtyShipped       int,    
    RemainQty        int,    
    Loadkey          NVARCHAR(10),
    UserDefine04     NVARCHAR(18), -- SOS127541   
	 MarkForCode	   NVARCHAR(30),	--GOH01
	 MarkForName	 NVARCHAR(45),	--GOH01
	 Division		 NVARCHAR(10))	--GOH01	
    
    
   CREATE TABLE #TEMPORD (    
       ExternOrderkey NVARCHAR(50) NULL,     --tlting_ext
       Orderkey NVARCHAR(10) NULL, -- SOS30230    
       SKU NVARCHAR(20),    
       OrderQty int ,    
       Flag NVARCHAR(1) )    
    
    
   CREATE TABLE #TEMPACK (    
       Cartonno int,    
       LabelNo NVARCHAR(20),   -- SOS61168           
       SKU NVARCHAR(20),    
       QtyPicked int ,    
       Flag NVARCHAR(1) )    
    
   CREATE TABLE #TEMPRESULT (    
     Pickslipno NVARCHAR(10),    
     ExternOrderkey NVARCHAR(50) NULL,      --tlting_ext
     Cartonno int,    
     LabelNo NVARCHAR(20),   -- SOS61168         
     Sku NVARCHAR(20),    
     QtyShipped int,    
   Orderkey NVARCHAR(10) ) -- SOS30447    
    
    
    SELECT @c_orderkey = Orderkey, @c_pickslipno = Pickslipno    
    FROM PACKHEADER (NOLOCK)    
    WHERE Loadkey = @c_LoadKey    
    
    
IF (@c_orderkey = '' OR @c_orderkey IS NULL) AND (@c_pickslipno <> '' AND @c_pickslipno IS NOT NULL)    
BEGIN    
    
 INSERT INTO #TEMPORD    
 SELECT ExternOrderkey,    
     Orderkey, -- SOS30230    
        SKU,    
        Sum(QtyAllocated + QtyPicked + ShippedQty ),    
        '0'     
 FROM ORDERDETAIL (NOLOCK)    
 WHERE Loadkey = @c_loadkey    
 GROUP BY ExternOrderkey, Sku    
       ,Orderkey -- SOS30230    
 ORDER BY Sku      
    
 INSERT INTO #TEMPACK    
 SELECT Cartonno,    
        LabelNo,  -- SOS61168    
        SKU,    
        Sum(Qty),    
        '0'     
 FROM PACKDETAIL (NOLOCK)    
 WHERE Pickslipno = @c_pickslipno    
 GROUP BY Cartonno, LabelNo, Sku    
 ORDER BY Sku      
    
 SELECT @n_cnt = Count(*)    
 FROM #TEMPACK    
    
 DECLARE Pack_Cur CURSOR fast_forward read_only FOR    
 SELECT * FROM #TEMPACK    
 OPEN Pack_Cur -- cur1    
 -- SOS61168    
 -- FETCH NEXT FROM Pack_Cur INTO  @c_cartonno, @c_sku, @n_qtypack, @c_flag    
 FETCH NEXT FROM Pack_Cur INTO  @c_cartonno, @c_labelno, @c_sku, @n_qtypack, @c_flag    
    
 DECLARE Order_Cur CURSOR  fast_forward read_only FOR    
 SELECT  --* SOS30230 & SOS30447    
       ExternOrderkey,SKU, OrderQty = SUM(OrderQty), Flag, Orderkey    
       FROM #TEMPORD    
 GROUP BY ExternOrderkey,SKU, Flag, Orderkey -- SOS30447    
 ORDER BY SKU    
 OPEN Order_Cur -- cur2    
    
 -- SOS30447    
 -- FETCH NEXT FROM Order_Cur INTO  @c_externorderkey, @c_sku, @n_orderqty, @c_flag    
 FETCH NEXT FROM Order_Cur INTO  @c_externorderkey, @c_sku, @n_orderqty, @c_flag, @c_orderkey2    
    
 SELECT @b_flag1 = 0 -- False    
 SELECT @b_flag2 = 0 -- False    
    
 SELECT @n_remainqtyord = @n_orderqty    
 SELECT @n_remainqtypack = @n_qtypack    
  
--     
--  OPEN Pack_Cur -- cur1    
--  OPEN Order_Cur -- cur2    
    
FR1:    
 IF @b_flag1 = 1 -- TRUE     
 BEGIN    
   -- SOS61168    
   -- FETCH NEXT FROM Pack_Cur INTO  @c_cartonno, @c_sku, @n_qtypack, @c_flag    
   FETCH NEXT FROM Pack_Cur INTO  @c_cartonno, @c_labelno, @c_sku, @n_qtypack, @c_flag    
 END    
    
FR2:    
 IF @b_flag2 = 1 -- TRUE    
 BEGIN    
  -- SOS30447    
  -- FETCH NEXT FROM Order_Cur INTO  @c_externorderkey, @c_sku, @n_orderqty, @c_flag    
   FETCH NEXT FROM Order_Cur INTO  @c_externorderkey, @c_sku, @n_orderqty, @c_flag, @c_orderkey2           
 END    
    
FR3:    
IF @b_flag1 = 1 AND @b_flag2 = 1    
BEGIN    
   -- SOS61168    
   -- FETCH NEXT FROM Pack_Cur INTO  @c_cartonno, @c_sku, @n_qtypack, @c_flag    
   FETCH NEXT FROM Pack_Cur INTO  @c_cartonno, @c_labelno, @c_sku, @n_qtypack, @c_flag    
  -- SOS30447    
  -- FETCH NEXT FROM Order_Cur INTO  @c_externorderkey, @c_sku, @n_orderqty, @c_flag    
   FETCH NEXT FROM Order_Cur INTO  @c_externorderkey, @c_sku, @n_orderqty, @c_flag, @c_orderkey2     
    
   SELECT @b_flag1 = 1 -- TRUE    
   SELECT @b_flag2 = 1 -- TRUE    
           
END    
    
WHILE(1=1)    
BEGIN    
    
   IF @b_flag1 = 1 AND @b_flag2 = 0    
   BEGIN    
     SELECT @n_remainqtypack = @n_qtypack    
     SELECT @b_flag1 = 0 -- FALSE    
   END    
   ELSE    
   IF @b_flag2 = 1 AND @b_flag1 = 0    
   BEGIN     
    SELECT @n_remainqtyord = @n_orderqty    
    SELECT @b_flag2 = 0 -- FALSE    
   END    
   IF @b_flag1 = 1 AND @b_flag2 = 1    
   BEGIN    
     SELECT @n_remainqtypack = @n_qtypack    
     SELECT @n_remainqtyord = @n_orderqty    
     SELECT @b_flag1 = 0     
     SELECT @b_flag2 = 0 -- FALSE     
  END    
    
 IF @n_remainqtypack - @n_remainqtyord > 0    
 BEGIN     
  IF @@FETCH_STATUS <> -1    
  BEGIN    
 -- SOS30447    
 -- INSERT INTO #TEMPRESULT ( Pickslipno, ExternOrderkey, Cartonno, Sku, QtyShipped)    
 -- VALUES ( @c_pickslipno, @c_externorderkey, @c_cartonno, @c_sku, @n_remainqtyord)    
    
   -- SOS61168    
   -- INSERT INTO #TEMPRESULT ( Pickslipno, ExternOrderkey, Cartonno, Sku, QtyShipped, Orderkey )    
   -- VALUES ( @c_pickslipno, @c_externorderkey, @c_cartonno, @c_sku, @n_remainqtyord, @c_orderkey2 )    
    
   INSERT INTO #TEMPRESULT ( Pickslipno, ExternOrderkey, Cartonno, LabelNo, Sku, QtyShipped, Orderkey )    
   VALUES ( @c_pickslipno, @c_externorderkey, @c_cartonno, @c_labelno, @c_sku, @n_remainqtyord, @c_orderkey2 )       
    
   SELECT @n_remainqtypack = @n_remainqtypack - @n_remainqtyord    
   SELECT @n_remainqtyord = 0    
    
   SELECT @b_flag1 = 0 -- FALSE    
   SELECT @b_flag2 = 1 -- TRUE    
    
   IF @n_remainqtypack = 0 GOTO FR3    
   ELSE    
   GOTO FR2    
    
 END -- @@FETCH_STATUS <> -1      
 ELSE    
  BEGIN    
    BREAK    
  END    
 END -- remainqty > 0    
 ELSE    
 IF @n_remainqtypack - @n_remainqtyord < 0    
 BEGIN    
  IF @@FETCH_STATUS <> -1    
  BEGIN    
 -- SOS30447    
 -- INSERT INTO #TEMPRESULT ( Pickslipno, ExternOrderkey, Cartonno, Sku, QtyShipped)    
 -- VALUES ( @c_pickslipno, @c_externorderkey, @c_cartonno, @c_sku, @n_remainqtypack)    
    
   -- SOS61168    
   -- INSERT INTO #TEMPRESULT ( Pickslipno, ExternOrderkey, Cartonno, Sku, QtyShipped, Orderkey )     
   -- VALUES ( @c_pickslipno, @c_externorderkey, @c_cartonno, @c_sku, @n_remainqtypack, @c_orderkey2 )    
    
   INSERT INTO #TEMPRESULT ( Pickslipno, ExternOrderkey, Cartonno, LabelNo, Sku, QtyShipped, Orderkey )     
   VALUES ( @c_pickslipno, @c_externorderkey, @c_cartonno, @c_labelno, @c_sku, @n_remainqtypack, @c_orderkey2 )    
    
   SELECT @n_remainqtyord = ABS(@n_remainqtypack - @n_remainqtyord)    
   SELECT @n_remainqtypack = 0    
       
   SELECT @b_flag1 = 1 -- TRUE    
   SELECT @b_flag2 = 0 -- FALSE    
    
   IF @n_remainqtyord = 0 GOTO FR3    
   ELSE    
    GOTO FR1      
    
  END -- @@FETCH_STATUS <> -1    
  ELSE    
  BEGIN    
   BREAK    
  END    
 END  -- remainqty < 0    
 ELSE     
 IF @n_remainqtypack - @n_remainqtyord = 0    
 BEGIN    
  IF @@FETCH_STATUS <> -1    
  BEGIN    
 -- SOS30447    
 -- INSERT INTO #TEMPRESULT ( Pickslipno, ExternOrderkey, Cartonno, Sku, QtyShipped)    
 -- VALUES ( @c_pickslipno, @c_externorderkey, @c_cartonno, @c_sku, @n_remainqtypack)    
    
   -- SOS61168    
   -- INSERT INTO #TEMPRESULT ( Pickslipno, ExternOrderkey, Cartonno, Sku, QtyShipped, Orderkey )    
   -- VALUES ( @c_pickslipno, @c_externorderkey, @c_cartonno, @c_sku, @n_remainqtypack, @c_orderkey2 )    
       
   INSERT INTO #TEMPRESULT ( Pickslipno, ExternOrderkey, Cartonno, LabelNo, Sku, QtyShipped, Orderkey )    
   VALUES ( @c_pickslipno, @c_externorderkey, @c_cartonno, @c_labelno, @c_sku, @n_remainqtypack, @c_orderkey2 )       
       
   SELECT @b_flag1 = 1 -- TRUE    
   SELECT @b_flag2 = 1 -- TRUE    
    
   GOTO FR3     
    
  END    
  ELSE    
  BEGIN    
    BREAK    
  END    
 END -- remainqty = 0    
END -- WHILE (1-1)    
END -- IF @c_orderkey = ''     
ELSE    
IF (@c_orderkey <> '' OR @c_orderkey IS NOT NULL) AND (@c_pickslipno <> '' AND @c_pickslipno IS NOT NULL)    
BEGIN    
     INSERT INTO #ExpList    
      SELECT PACKHeader.PickSlipNo,      
      ORDERS.ExternOrderKey,     
      ORDERS.OrderGroup,     
      CL.Description ,     
      ISNULL(ORDERS.BuyerPO, ''),     
      ISNULL(CLF.SHORT, ''),    
      CONVERT ( NVARCHAR(10), MBOL.EditDate, 121 ),  -- ETD, Modified By MaryVong on 06-Jan-2004 (FBR#18640)    
      CASE WHEN CLC.Short IS NULL OR ISNUMERIC(CLC.Short) <> 1 THEN CONVERT ( NVARCHAR(10), MBOL.EditDate, 121 )      
           ELSE CASE WHEN ORDERS.IntermodalVehicle = 'ILOE' THEN
                  CONVERT( NVARCHAR(10), DateAdd(hour, Floor(Cast(CLC.Short as real)), convert(datetime,convert(char(8),MBOL.EditDate,112)+ ' 23:59:59')), 121) --NJOW01
                ELSE
                  CONVERT( NVARCHAR(10), DateAdd(hour, Floor(Cast(CLC.Short as real) * 24), MBOL.EditDate ), 121)
                END
      END, -- ETA (ETA = ETD + LeadTime), Modified By MaryVong on 06-Jan-2004 (FBR#18640)    
      ORDERS.ConsigneeKey, -- (YokeBeen01)     
      ISNULL(ORDERS.C_Contact1, ''),     
      ISNULL(LTRIM(RTRIM(ORDERS.C_Address3)), '') + ISNULL(LTRIM(RTRIM(ORDERS.C_Address4)), '') +      
		ISNULL(LTRIM(RTRIM(ORDERS.C_Address2)), ''), -- (YokeBeen01)    
      PACKDETAIL.CartonNo,    
      PACKDETAIL.LabelNo,   -- SOS61168    
      SKU.SUSR4 ,     
      SKU.SKU,    
      LEFT(ISNULL(LTRIM(SKU.SKU),''), 6),     
      SubString(ISNULL(LTRIM(SKU.SKU),''), 7, 3),     
      '00',               -- (YokeBeen01) - Dimension    
      SubString(ISNULL(LTRIM(ORDERDETAIL.Lottable02),''), 1, 2), -- (YokeBeen01) - Quality    
      ISNULL(LTRIM(ORDERDETAIL.UOM),''),         -- (YokeBeen01) - UOM    
      SubString(ISNULL(LTRIM(SKU.Sku),''), 10, 5),     -- (YokeBeen01) - Size    
      -- SOS66809 Get UPC from AltSku    
      -- ISNULL(SKU.RetailSku, ''),       -- (YokeBeen01) - UPC    
      ISNULL(SKU.AltSku, ''),                         -- UPC    
      SUM(PACKDETAIL.Qty),    
      0, -- remain qty     
      @c_loadkey  ,
      ORDERDETAIL.UserDefine04  AS NikeOrderNo -- SOS127541
		, ISNULL(ORDERS.B_Contact1,''), ISNULL(LTRIM(RTRIM(ORDERS.B_Company)),'')	--GOH01
		, ISNULL(ORDERS.Stop,'')	--GOH01
      FROM ORDERS (NOLOCK)     
      INNER JOIN LoadPlanDetail (NOLOCK) ON (LoadPlanDetail.OrderKey = ORDERS.OrderKey)    
      INNER JOIN Codelkup CL (NOLOCK) ON (CL.Code = ORDERS.Type AND CL.ListName = 'ORDERTYPE')     
      LEFT OUTER JOIN CodeLkup CLF (NOLOCK) ON (ORDERS.Facility = CLF.Code AND CLF.ListName = 'Facility')     
      INNER JOIN ORDERDETAIL (NOLOCK) ON (OrderDetail.OrderKey = ORDERS.OrderKey)     
      INNER JOIN PACKHEADER (NOLOCK) ON (PACKHEADER.OrderKey = ORDERS.OrderKey )     
      INNER JOIN PACKDETAIL (NOLOCK) ON (PACKDETAIL.PickSlipNo = PACKHeader.PickSlipNo     
                                         AND PACKDETAIL.StorerKey = OrderDetail.StorerKey     
                                         AND PACKDETAIL.SKU = OrderDetail.SKU)     
      LEFT OUTER JOIN UPC (NOLOCK) ON (ORDERDETAIL.StorerKey = UPC.StorerKey AND ORDERDETAIL.SKU = UPC.SKU)     
      LEFT OUTER JOIN SKU (NOLOCK) ON (ORDERDETAIL.StorerKey = SKU.StorerKey AND ORDERDETAIL.SKU = SKU.SKU)    
      INNER JOIN MBOLDETAIL (NOLOCK) ON (MBOLDETAIL.OrderKey = ORDERS.OrderKey)    
      INNER JOIN MBOL (NOLOCK) ON (MBOL.MBOLKey = MBOLDETAIL.MBOLKey)    
      LEFT OUTER JOIN CODELKUP CLC (NOLOCK) ON (CLC.LONG = ORDERS.Facility AND   
                CLC.Description = ORDERS.C_City AND   -- (YokeBeen03)    
                CLC.ListName = 'CityLdTime'     
                AND CAST(CLC.Notes AS NVARCHAR(30)) = Orders.intermodalvehicle) -- (Vanessa01)       
    WHERE LoadPlanDetail.LoadKey =  @c_LoadKey    
      AND   ISNULL(dbo.fnc_RTRIM(PACKHEADER.OrderKey),'') IS NOT NULL    
      AND   ISNULL(dbo.fnc_RTRIM(PACKHEADER.OrderKey),'') <> ''    
      GROUP BY     
      PACKHeader.PickSlipNo, ORDERS.ExternOrderKey,      
      ORDERS.OrderGroup, CL.Description,     
      ORDERS.BuyerPO, CLF.SHORT,     
      CLC.Short,    
      MBOL.EditDate,     
      ORDERS.ConsigneeKey,  -- (YokeBeen01)    
      ORDERS.C_Contact1,     
      ISNULL(LTRIM(RTRIM(ORDERS.C_Address3)), '') + ISNULL(LTRIM(RTRIM(ORDERS.C_Address4)), '') +      
      ISNULL(LTRIM(RTRIM(ORDERS.C_Address2)), ''),  -- (YokeBeen01)    
      PACKDETAIL.CartonNo,     
      PACKDETAIL.LabelNo,   -- SOS61168    
      SKU.SUSR4,     
      SKU.SKU,    
      -- SOS66809 Get UPC from AltSku      
  -- SubString(dbo.fnc_LTRIM(ORDERDETAIL.Lottable02), 1, 2), ORDERDETAIL.UOM, ISNULL(SKU.RetailSku, '')  -- (YokeBeen01)    
   SubString(ISNULL(LTRIM(ORDERDETAIL.Lottable02),''), 1, 2), ORDERDETAIL.UOM, ISNULL(SKU.AltSku, '') ,Orderdetail.userdefine04,  --SOS127541   
	ORDERS.IntermodalVehicle --NJOW01
	,ISNULL(ORDERS.B_Contact1,''), ISNULL(LTRIM(RTRIM(ORDERS.B_Company)),'')	--GOH01
	, ISNULL(ORDERS.Stop,'')	--GOH01
END 
ELSE     
IF (@c_pickslipno = '' OR @c_pickslipno IS NULL)      
BEGIN    
 DROP TABLE #ExpList    
 DROP TABLE #TEMPORD    
 DROP TABLE #TEMPACK    
 DROP TABLE #TEMPRESULT    
    
 GOTO NO_RESULT    
END    
    
IF @c_orderkey <> '' AND @c_orderkey IS NOT NULL    
BEGIN     
  SELECT PackListNo, ExternOrderKey, OrderGroup, OrderType, BuyerPO, convert(NVARCHAR(10), WhCode),     
  ETD, ETA, CustomerCode,         
         -- SOS61168        
         -- CustomerName, CustAddr, CartonNo, GPC, Style, Color, Dimension, Quality, UOM, Size, UPC, QtyShipped        
         CustomerName, Convert(NVARCHAR(90), CustAddr), 
	Convert(NVARCHAR(4),CartonNo),     
   GPC, Style, Color, Dimension, Quality, UOM, Size, UPC, QtyShipped, LabelNo    
  ,UserDefine04  AS NikeOrderNo --GOH01
  , MarkForCode ,Convert(NVARCHAR(90), MarkForName) AS MarkForName, Division	--GOH01      
  FROM #ExpList        
  ORDER BY ExternOrderKey, Cartonno        
        
    
  DROP TABLE #ExpList    
    
END    
ELSE    
IF (@c_orderkey <> '' OR @c_orderkey IS NOT NULL) AND (@c_pickslipno <> '' AND @c_pickslipno IS NOT NULL)    
BEGIN    
    
 CLOSE Pack_Cur    
 CLOSE Order_Cur    
 DEALLOCATE Pack_Cur    
 DEALLOCATE Order_Cur    
    
 IF @b_debug = 1     
 BEGIN    
 SELECT * FROM #TEMPRESULT (NOLOCK)    
 END    
    
 SELECT #TEMPRESULT.Pickslipno,      
    #TEMPRESULT.ExternOrderKey,       
    ORDERS.OrderGroup,       
    CL.Description,       
    ISNULL(ORDERS.BuyerPO, '') AS buyerPO,       
     CONVERT(NVARCHAR(10), ISNULL(CLF.SHORT, '')) as Short,      -- tlting01    
    CONVERT ( NVARCHAR(10), MBOL.EditDate, 121 ) as Editdate,  -- ETD, Modified By MaryVong on 06-Jan-2004 (FBR#18640)      
      CASE WHEN CLC.Short IS NULL OR ISNUMERIC(CLC.Short) <> 1 THEN CONVERT ( NVARCHAR(10), MBOL.EditDate, 121 )       
           ELSE CASE WHEN ORDERS.IntermodalVehicle = 'ILOE' THEN
                  CONVERT( NVARCHAR(10), DateAdd(hour, Floor(Cast(CLC.Short as real)), convert(datetime,convert(char(8),MBOL.EditDate,112)+ ' 23:59:59')), 121) --NJOW01
                ELSE
                  CONVERT( NVARCHAR(10), DateAdd(hour, Floor(Cast(CLC.Short as real) * 24), MBOL.EditDate ), 121)
                END
      END as ETA, -- ETA (ETA = ETD + LeadTime), Modified By MaryVong on 06-Jan-200 (FBR#18640)      
        ORDERS.ConsigneeKey, -- (YokeBeen01)       
        ISNULL(ORDERS.C_Contact1, '') as contact1,       
    CONVERT(NVARCHAR(90), ISNULL(LTRIM(RTRIM(ORDERS.C_Address3)), '') + ISNULL(LTRIM(RTRIM(ORDERS.C_Address4)), '') +      
    ISNULL(LTRIM(RTRIM(ORDERS.C_Address2)), '') ) as address1, -- (YokeBeen01)       -- tlting01    
    Convert(NVARCHAR(4), #TEMPRESULT.CartonNo),        -- tlting01    
    SKU.SUSR4,       
    Convert(NVARCHAR(6), LEFT(ISNULL(LTRIM(SKU.SKU),''), 6)) as style,        -- tlting01    
    convert(NVARCHAR(7), SubString(ISNULL(LTRIM(SKU.SKU),''), 7, 3) ) as color,        -- tlting01    
    '00' as Dimension,               -- (YokeBeen01) - Dimension      
    convert(NVARCHAR(2), SubString(ISNULL(LTRIM(ORDERDETAIL.Lottable02),''), 1, 2) ) as Quality, -- (YokeBeen01) - Quality       -- tlting01    
    Convert(NVARCHAR(2), ISNULL(LTRIM(ORDERDETAIL.UOM),'')) as uom,           -- (YokeBeen01) - UOM       -- tlting01    
    Convert(NVARCHAR(5), SubString(ISNULL(LTRIM(SKU.Sku),''), 10, 5) ) as size,       -- (YokeBeen01) - Size       -- tlting01    
    -- SOS66809 Get UPC from AltSku      
    -- ISNULL(SKU.RetailSku, '') as UPC,         -- (YokeBeen01) - UPC      
    Convert(NVARCHAR(30), ISNULL(SKU.AltSku, '') ) as UPC,       -- tlting01    
    #TEMPRESULT.QtyShipped,      
    #TEMPRESULT.LabelNo,   -- SOS61168 Request by NIKE (soft-copy of this report is imported to NIKE system)         
    ORDERDETAIL.UserDefine04 AS  NikeOrderNo --SOS127541
	 ,ISNULL(ORDERS.B_Contact1,'') AS MarkForCode	--GOH01
	 ,CONVERT(NVARCHAR(90), ISNULL(LTRIM(RTRIM(ORDERS.B_Company)),'')) AS MarkForName	--GOH01
	 ,ISNULL(ORDERS.Stop,'')	--GOH01
    FROM #TEMPRESULT          
-- Start : SOS30447      
-- INNER JOIN ORDERS (NOLOCK) ON (ORDERS.ExternOrderkey = #TEMPRESULT.ExternOrderkey)        
INNER JOIN ORDERS (NOLOCK) ON (ORDERS.Orderkey = #TEMPRESULT.Orderkey)        
-- End : SOS30447      
        INNER JOIN Codelkup CL (NOLOCK) ON (CL.Code = ORDERS.Type AND CL.ListName = 'ORDERTYPE')         
        LEFT OUTER JOIN CodeLkup CLF (NOLOCK) ON (ORDERS.Facility = CLF.Code AND CLF.ListName = 'Facility')         
        INNER JOIN ORDERDETAIL (NOLOCK) ON (ORDERDETAIL.ExternOrderkey = ORDERS.ExternOrderkey         
                                            AND ORDERDETAIL.Orderkey = ORDERS.Orderkey       
                AND ORDERDETAIL.SKU = #TEMPRESULT.SKU)    -- (YokeBeen02)      
      LEFT OUTER JOIN UPC (NOLOCK) ON (ORDERDETAIL.StorerKey = UPC.StorerKey AND #TEMPRESULT.SKU = UPC.SKU)         
        LEFT OUTER JOIN SKU (NOLOCK) ON (ORDERDETAIL.StorerKey = SKU.StorerKey AND #TEMPRESULT.SKU = SKU.SKU)      
    INNER JOIN MBOLDETAIL (NOLOCK) ON (MBOLDETAIL.OrderKey = ORDERS.OrderKey)       
    INNER JOIN MBOL (NOLOCK) ON (MBOL.MBOLKey = MBOLDETAIL.MBOLKey)      
    LEFT OUTER JOIN CODELKUP CLC (NOLOCK) ON (CLC.LONG = ORDERS.Facility AND       
                  CLC.Description = ORDERS.C_City AND   -- (YokeBeen03)      
                  CLC.ListName = 'CityLdTime'      
                  AND CAST(CLC.Notes AS NVARCHAR(30)) = Orders.intermodalvehicle) -- (Vanessa01)             
 GROUP BY #TEMPRESULT.ExternOrderKey, #TEMPRESULT.Pickslipno,      
      ORDERS.OrderGroup, CL.Description,       
          ORDERS.BuyerPO, CLF.SHORT,         
    CLC.Short,      
    MBOL.EditDate,         
          ORDERS.ConsigneeKey,  -- (YokeBeen01)      
          ORDERS.C_Contact1,         
          ISNULL(LTRIM(RTRIM(ORDERS.C_Address3)), '') + ISNULL(LTRIM(RTRIM(ORDERS.C_Address4)), '') +       
    ISNULL(LTRIM(RTRIM(ORDERS.C_Address2)), ''),    -- (YokeBeen01)      
          #TEMPRESULT.CartonNo,               
          SKU.SUSR4,          
          SKU.SKU,         
          -- SOS66809 Get UPC from AltSku      
    -- SubString(dbo.fnc_LTRIM(ORDERDETAIL.Lottable02), 1, 2), ORDERDETAIL.UOM, ISNULL(SKU.RetailSku, ''),  -- (YokeBeen01)       
    SubString(ISNULL(LTRIM(ORDERDETAIL.Lottable02),''), 1, 2), ORDERDETAIL.UOM, ISNULL(SKU.AltSku, ''),      
          #TEMPRESULT.QtyShipped,      
      #TEMPRESULT.LabelNo,   -- SOS61168       
      OrderDetail.UserDefine04, --SOS127541
    	ORDERS.IntermodalVehicle --NJOW01
	   ,ISNULL(ORDERS.B_Contact1,''), CONVERT(NVARCHAR(90), ISNULL(LTRIM(RTRIM(ORDERS.B_Company)),''))	--GOH01
		,ISNULL(ORDERS.Stop,'')	--GOH01
 DROP TABLE #ExpList    
 DROP TABLE #TEMPORD    
 DROP TABLE #TEMPACK    
 DROP TABLE #TEMPRESULT    
    
END    
    
NO_RESULT:    
    
END -- Procedure    


GO