SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
 


/************************************************************************/
/* Stored Procedure: isp_DuplicateNIKESKU                               */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Auto duplicate\Update NIKE SKU from 1 Interface Storer      */
/*          to another NIKE Storerkey                                   */
/*                                                                      */
/* Return Status: None                                                  */
/*                                                                      */
/* Usage: For Backend Schedule job                                      */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: SQL Schedule Job                                          */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Ver  Author   Purposes                                  */
/* 17-Dec-2020  1.0  TLTING   Initital version                          */
/* 12-Jan-2021  1.1  TLTING01 Bug fix                                   */  
/* 19-Jan-2021  1.2  TLTING02 Lottable03label default ''                */  
/*                                                                      */
/************************************************************************/



CREATE PROC [dbo].[isp_DuplicateNIKESKU]    
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF   
  
   DECLARE @c_FromStorerkey  NVARCHAR(15)  
   DECLARE @c_NewStorerkey   NVARCHAR(15)  
   DECLARE @c_SKU            NVARCHAR(20)  
   DECLARE @c_NewSKU         NVARCHAR(20)  
  
   SET @c_FromStorerkey = 'NIKECN'  
   SET @c_NewStorerkey  = '18467'  
  
   Declare @c_DESCR              NVARCHAR(60)  
   Declare @c_ALTSKU             NVARCHAR(20)  
   Declare @c_SKUGROUP           NVARCHAR(10)  
   Declare @c_BUSR4              NVARCHAR(200)  
   Declare @c_Price              money  
   Declare @c_BUSR7              NVARCHAR(30)  
   Declare @c_PackQTYIndicator   INT  
   
  
   Declare @dt_FromDate     DATETIME  
   Declare @dt_ToDate       DATETIME  
   
    -- last 24 hour  
   SELECT @dt_ToDate = CONVERT( DATETIME, CONVERT( VARCHAR(10), GETDATE(), 120) + ' ' + RIGHT('00' + CONVERT(VARCHAR(2), DATEPART(HOUR, GETDATE()) ), 2) + ':00:00' )  
   SELECT @dt_FromDate = DATEADD(DAY, -1 , @dt_ToDate )   
   
     
          
   IF OBJECT_ID('tempdb..#SKU_New') IS NOT NULL          
      DROP TABLE #SKU_New          
  
   CREATE TABLE #SKU_New  
   ( StorerKey             NVARCHAR(15) NOT NULL,  
      Sku                   NVARCHAR(20) NOT NULL,  
      DESCR                   NVARCHAR(60) NULL,  
      SUSR3                   NVARCHAR(18) NULL,  
      SUSR4                   NVARCHAR(18) NULL,  
      ALTSKU                NVARCHAR(20) NULL,  
      PACKKey                NVARCHAR(10) NULL,  
      CLASS                   NVARCHAR(10) NULL,  
      SKUGROUP                NVARCHAR(10) NULL,  
      Tariffkey             NVARCHAR(10) NULL,  
      BUSR1                   NVARCHAR(30) NULL,  
      BUSR2                   NVARCHAR(30) NULL,  
      BUSR3                   NVARCHAR(30) NULL,  
      BUSR4                   NVARCHAR(200) NULL,  
      LOTTABLE01LABEL       NVARCHAR(20) NULL,  
      LOTTABLE02LABEL       NVARCHAR(20) NULL,  
      LOTTABLE03LABEL       NVARCHAR(20) NULL,   
      LOTTABLE05LABEL       NVARCHAR(20) NULL,  
      StrategyKey           NVARCHAR(10) NULL,  
      CartonGroup             NVARCHAR(10) NULL,  
      PutCode                NVARCHAR(10) NULL,  
      PutawayZone             NVARCHAR(10) NULL,  
      InnerPack             INT NULL,  
      ABC                   NVARCHAR(5) NULL,  
      Price                   MONEY NULL,  
      ReceiptInspectionLoc    NVARCHAR(10) NULL,  
      LotxIdDetailOtherlabel1 NVARCHAR(30) NULL,  
      LotxIdDetailOtherlabel2 NVARCHAR(30) NULL,  
      LotxIdDetailOtherlabel3 NVARCHAR(30) NULL,  
      SkuStatus             NVARCHAR(10) NULL,  
      itemclass             NVARCHAR(10) NULL,  
      Facility                NVARCHAR(5) NULL,  
      BUSR6                   NVARCHAR(30) NULL,  
      BUSR7                   NVARCHAR(30) NULL,  
      BUSR8                   NVARCHAR(30) NULL,  
      BUSR9                   NVARCHAR(30) NULL,  
      BUSR10                NVARCHAR(30) NULL,  
      PrePackIndicator       NVARCHAR(30) NULL,  
      PackQtyIndicator       int NULL,  
      DisableABCCalc          NVARCHAR(1) NULL,  
      ABCPeriod             INT NULL,  
      LottableCode          nvarchar(30) NULL,  
      CONSTRAINT [PKSKU] PRIMARY KEY CLUSTERED ( [StorerKey] ASC, [Sku] ASC ) )  
    
   -- BUSR4_BITMAP  
  
   INSERT INTO #SKU_New (  
       StorerKey               
      , Sku                     
      , DESCR                     
      , SUSR3                     
      , SUSR4                     
      , ALTSKU                  
      , PACKKey                  
      , CLASS                     
      , SKUGROUP                  
      , Tariffkey               
      , BUSR1                     
      , BUSR2                     
      , BUSR3                     
      , BUSR4                     
      , LOTTABLE01LABEL         
      , LOTTABLE02LABEL         
      , LOTTABLE03LABEL         
      , LOTTABLE05LABEL         
      , StrategyKey             
      , CartonGroup               
      , PutCode                  
      , PutawayZone               
      , InnerPack               
      , ABC                     
      , Price                     
      , ReceiptInspectionLoc      
      , LotxIdDetailOtherlabel1   
      , LotxIdDetailOtherlabel2   
      , LotxIdDetailOtherlabel3   
      , SkuStatus               
      , itemclass               
      , Facility                  
      , BUSR6                     
      , BUSR7                     
      , BUSR8                     
      , BUSR9                     
      , BUSR10                  
      , PrePackIndicator         
      , PackQtyIndicator         
      , DisableABCCalc            
      , ABCPeriod               
      , LottableCode    
   )    
   SELECT   
     @c_NewStorerkey               
      , Sku                     
      , DESCR                     
      , SUSR3                     
      , SUSR4                     
      , ALTSKU                  
      , PACKKey                  
      , CLASS                     
      , SKUGROUP                  
      , Tariffkey               
      , BUSR1                     
      , BUSR2                     
      , BUSR3                     
      , BUSR4                     
      , 'Grade'             -- LOTTABLE01LABEL         
      , 'Reason'           -- LOTTABLE02LABEL         
      , LOTTABLE03LABEL         
      , LOTTABLE05LABEL         
      , 'ECOM_SKPP'        -- StrategyKey             
      , CartonGroup               
      , PutCode                  
      , PutawayZone               
      , InnerPack               
      , ABC                     
      , Price                     
      , ReceiptInspectionLoc      
      , LotxIdDetailOtherlabel1   
      , LotxIdDetailOtherlabel2   
      , LotxIdDetailOtherlabel3   
      , SkuStatus               
      , itemclass               
      , ''  -- Default Facility                  
      , BUSR6                     
      , BUSR7                     
      , BUSR8                     
      , BUSR9                     
      , BUSR10                  
      , '0'  --- PrePackIndicator         
      , PackQtyIndicator         
      , DisableABCCalc            
      , ABCPeriod               
      , 'NIKE'    -- LottableCode            
   FROM SKU (NOLOCK)  
   WHERE  Storerkey = @c_FromStorerkey  
   AND Editdate BETWEEN  @dt_FromDate AND @dt_ToDate      
  
   UPDATE #SKU_New  
   SET SKU =  ISNULL( LTRIM(RTRIM(SKU)), ''), itemclass = ISNULL( LTRIM(RTRIM(itemclass)) ,  '' )  
   --  SKU        - 5112823048  need  tranfer  to  511282-304-8  
   --  itemclass  - 511282304  need  tranfer   to  511282-304  
      
  
   UPDATE #SKU_New  
   SET SKU =  CASE WHEN LEN(SKU) >= 6 AND LEN(SKU) <= 9 THEN  
                       LEFT(SKU,  6) + '-' + SUBSTRING(SKU, 7, 3)  
                  WHEN LEN(SKU) > 9 THEN  
                        CONVERT( NVARCHAR(20), LEFT(SKU,  6) + '-' + SUBSTRING(SKU, 7, 3) + '-' + RIGHT (SKU , LEN(SKU) - 9) )  
                  ELSE 
                      SKU      
                  END ,  
   itemclass =  CASE WHEN LEN(Itemclass) > 6   
                  THEN  CONVERT( NVARCHAR(10), left(itemclass,  6) + '-'  + RIGHT (itemclass , LEN(itemclass) - 6))  
                  ELSE
                     Itemclass
               END    
   
  
 DECLARE SKUItem_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
  SELECT A.SKU   
      , A.DESCR              
      , A.ALTSKU             
      , A.SKUGROUP           
      , A.BUSR4              
      , A.Price              
      , A.BUSR7              
      , A.PackQTYIndicator   
    FROM #SKU_New  A (NOLOCK)    
      WHERE EXISTS ( SELECT 1 FROM SKU (NOLOCK)   
               WHERE  SKU.Storerkey = A.Storerkey AND SKU.SKU = A.SKU )  
  
 OPEN SKUItem_cur   
 FETCH NEXT FROM SKUItem_cur INTO @c_SKU, @c_DESCR, @c_ALTSKU, @c_SKUGROUP, @c_BUSR4             
                        , @c_Price, @c_BUSR7, @c_PackQTYIndicator     
  
 WHILE @@FETCH_STATUS = 0   
 BEGIN   
      BEGIN TRAN   
   UPDATE dbo.SKU  
         SET                 
         DESCR            = @c_DESCR,   
         ALTSKU           = @c_ALTSKU,  
         SKUGROUP         = @c_SKUGROUP,  
         BUSR4            = @c_BUSR4,  
         Price            = @c_Price,  
         BUSR7            = @c_BUSR7,  
         PackQTYIndicator = @c_PackQTYIndicator,  
         Editdate         = GETDATE(),  
         Editwho          = 'U#'+SUSER_SNAME(),  
         TrafficCop       = NULL  
         WHERE  Storerkey = @c_NewStorerkey AND SKU = @c_SKU  
      IF @@ERROR <> 0    
      BEGIN    
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
         COMMIT TRAN  
      END  
  
  FETCH NEXT FROM SKUItem_cur INTO @c_SKU, @c_DESCR, @c_ALTSKU, @c_SKUGROUP, @c_BUSR4             
                        , @c_Price, @c_BUSR7, @c_PackQTYIndicator   
 END  
 CLOSE SKUItem_cur   
 DEALLOCATE SKUItem_cur  

  While 1=1
  BEGIN  
     INSERT INTO SKU  ( StorerKey               
         , Sku                     
         , DESCR                     
         , SUSR3                     
         , SUSR4                     
         , ALTSKU                  
         , PACKKey                  
         , CLASS                     
         , SKUGROUP                  
         , Tariffkey               
         , BUSR1                     
         , BUSR2                     
         , BUSR3                     
         , BUSR4                     
         , LOTTABLE01LABEL         
         , LOTTABLE02LABEL         
         , LOTTABLE03LABEL         
         , LOTTABLE05LABEL         
         , StrategyKey             
         , CartonGroup               
         , PutCode                  
         , PutawayZone               
         , InnerPack               
         , ABC                     
         , Price                     
         , ReceiptInspectionLoc      
         , LotxIdDetailOtherlabel1   
         , LotxIdDetailOtherlabel2   
         , LotxIdDetailOtherlabel3   
         , SkuStatus               
         , itemclass               
         , Facility                  
         , BUSR6                     
         , BUSR7                     
         , BUSR8                     
         , BUSR9                     
         , BUSR10                  
         , PrePackIndicator         
         , PackQtyIndicator         
         , DisableABCCalc            
         , ABCPeriod               
         , LottableCode  
         , Addwho, Editwho)  
  
      SELECT TOP 10000  StorerKey               
      , Sku                     
      , DESCR                     
      , SUSR3                     
      , SUSR4                     
      , ALTSKU                  
      , PACKKey                  
      , CLASS                     
      , SKUGROUP                  
      , Tariffkey               
      , BUSR1                     
      , BUSR2                     
      , BUSR3                     
      , BUSR4                     
      , 'Grade'            -- LOTTABLE01LABEL         
      , 'Reason'           -- LOTTABLE02LABEL         
      , ''                 -- LOTTABLE03LABEL         
      , LOTTABLE05LABEL         
      , 'ECOM_SKPP'        -- StrategyKey          
      , CartonGroup               
      , PutCode                  
      , PutawayZone               
      , InnerPack               
      , ABC                     
      , Price                     
      , ReceiptInspectionLoc      
      , LotxIdDetailOtherlabel1   
      , LotxIdDetailOtherlabel2   
      , LotxIdDetailOtherlabel3   
      , SkuStatus               
      , itemclass               
       , ''             -- Default Facility                  
      , BUSR6                     
      , BUSR7                     
      , BUSR8                     
      , BUSR9                     
      , BUSR10                  
      , '0'             -- PrePackIndicator         
      , PackQtyIndicator         
      , DisableABCCalc            
      , ABCPeriod               
      , 'NIKE'          -- LottableCode            
      , 'A#'+SUSER_SNAME()  
      , 'A#'+SUSER_SNAME()  
      FROM #SKU_New A  
       WHERE NOT EXISTS ( SELECT 1 FROM SKU (NOLOCK)   
                  WHERE  SKU.Storerkey = A.Storerkey AND SKU.SKU = A.SKU )  
   
 		IF @@ROWCOUNT  = 0
		   break 
	END 
END  

GO