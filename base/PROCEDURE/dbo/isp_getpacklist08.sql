SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
    
    
/************************************************************************/    
/* Store Procedure: isp_GetPackList08                                   */    
/* Creation Date:24/01/2017                                             */    
/* Copyright: IDS                                                       */    
/* Written by:CSCHONG                                                   */    
/*                                                                      */    
/* Purpose:WMS-974 - [TW] K-Swiss - Pack Summary Report                 */    
/*                                                                      */    
/* Called By:r_dw_print_packlist_08                                     */    
/*                                                                      */    
/* PVCS Version: 1.3 (Unicode)                                          */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author        Purposes                                  */
/* 23-MAR-2017  JyhBin    1.0 Order by Externorderkey                   */      
/* 07-JUNE-2018 CSCHONG   1.1 WMS-5239 add new field (CS01)             */   
/* 21-AUG-2018  CSCHONG   1.2 WMS-5904 - Revised field logic (CS02)     */ 
/* 24-Dec-2020  WLChooi   1.3 WMS-15885 - Show Qty = 0 on report if the */
/*                            StyleColor not allocated (WL01)           */
/* 11-Jan-2021  WLChooi   1.4 WMS-15885 - Fix Total Qty issue (WL02)    */
/************************************************************************/    
    
CREATE PROC [dbo].[isp_GetPackList08]     
           (@c_LoadKey NVARCHAR(10)    
           --,@c_DWCategory  NVARCHAR(1) = 'H'    
           --,@c_style       NVARCHAR(20) = ''    
           --,@c_color       NVARCHAR(10) = ''    
)    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @c_PickSlipNo      NVARCHAR(10),    
           @c_OrderKey        NVARCHAR(10),    
           @c_getOrderkey     NVARCHAR(10),    
           @c_OrderGroup      NVARCHAR(10),    
           @c_ExternOrderKey  NVARCHAR(30),    
           @c_Route           NVARCHAR(10),    
           @c_Notes           NVARCHAR(255),    
           @d_OrderDate       datetime,    
           @c_ConsigneeKey    NVARCHAR(15),    
           @c_Company         NVARCHAR(45),    
           @d_DeliveryDate    datetime,    
           @c_GetStyle        NVARCHAR(20),    
           @c_GetColor        NVARCHAR(10),    
           @c_GetSizeList     NVARCHAR(150),    
           @c_Sku             NVARCHAR(20),    
           @c_PrevStyle       NVARCHAR(20),    
           @c_PreColor        NVARCHAR(10),    
           @c_SkuSize         NVARCHAR(5),    
           @c_PreSkuSize      NVARCHAR(5),    
           @n_Qty             int,    
           @c_Floor           NVARCHAR(1),    
           @c_TempOrderKey    NVARCHAR(10),    
           @c_TempFloor       NVARCHAR(1),    
           @c_TempSize        NVARCHAR(5),    
           @n_TempQty         int,    
           @c_PrevOrderKey    NVARCHAR(10),    
           @c_PrevFloor       NVARCHAR(1),    
           @b_success         int,    
           @n_err             int,    
           @c_errmsg          NVARCHAR(255),    
           @n_Count           int,    
           @c_Column          NVARCHAR(10),    
           @c_SkuSize1        NVARCHAR(5),    
           @c_SkuSize2        NVARCHAR(5),    
           @c_SkuSize3        NVARCHAR(5),    
           @c_SkuSize4        NVARCHAR(5),    
           @c_SkuSize5        NVARCHAR(5),    
           @c_SkuSize6        NVARCHAR(5),    
           @c_SkuSize7        NVARCHAR(5),    
           @c_SkuSize8        NVARCHAR(5),    
           @c_SkuSize9        NVARCHAR(5),    
           @c_SkuSize10       NVARCHAR(5),    
           @c_SkuSize11       NVARCHAR(5),    
           @c_SkuSize12       NVARCHAR(5),    
           @c_SkuSize13       NVARCHAR(5),    
           @c_SkuSize14       NVARCHAR(5),    
           @c_SkuSize15       NVARCHAR(5),    
           @c_SkuSize16       NVARCHAR(5),    
           @c_SkuSize17       NVARCHAR(5),    
           @c_SkuSize18       NVARCHAR(5),    
           @c_SkuSize19       NVARCHAR(5),    
           @c_SkuSize20       NVARCHAR(5),    
           @c_SkuSize21       NVARCHAR(5),    
           @c_SkuSize22       NVARCHAR(5),    
           @c_SkuSize23       NVARCHAR(5),    
           @c_SkuSize24       NVARCHAR(5),    
           @n_Qty1            int,    
           @n_Qty2            int,    
           @n_Qty3            int,    
           @n_Qty4            int,    
           @n_Qty5            int,    
           @n_Qty6            int,    
           @n_Qty7            int,    
           @n_Qty8            int,    
           @n_Qty9            int,    
           @n_Qty10           int,    
           @n_Qty11           int,    
           @n_Qty12           int,    
           @n_Qty13           int,    
           @n_Qty14           int,    
           @n_Qty15           int,    
           @n_Qty16           int,    
           @n_Qty17           int,    
           @n_Qty18           int,    
           @n_Qty19           int,    
           @n_Qty20           int,    
           @n_Qty21           int,    
           @n_Qty22           int,    
           @n_Qty23           int,    
           @n_Qty24           int,    
           @c_Bin             NVARCHAR(2),    
           @C_BUSR6           NVARCHAR(30),    
           @c_LogicalLocation NVARCHAR(18),       
           @c_Sort            NVARCHAR(5),    
           @c_storerkey       NVARCHAR(15),    
           --@c_Style           NVARCHAR(20),    
           --@c_Color           NVARCHAR(10),    
           @c_DelimiterSign   NVARCHAR(1),    
           @c_SizeList        NVARCHAR(4000),    
           @n_seqno           INT,    
           @c_ColValue        NVARCHAR(20),    
           @n_rowid            INT        
    
   DECLARE @b_debug int    
   SELECT @b_debug = 0    
    
   CREATE TABLE #TempPacklist08 (    
             STOCompany       NVARCHAR(45) NULL,    
             CLogo            NVARCHAR(60) NULL,                  
               Loadkey          NVARCHAR(10) NULL,    
               OrderKey         NVARCHAR(10) NULL,    
               InvoiceNo        NVARCHAR(10) NULL,    
               CCompany         NVARCHAR(45) NULL,    
               B_Vat            NVARCHAR(18) NULL,    
               BAddress         NVARCHAR(150) NULL,     
               CAddress         NVARCHAR(150) NULL,     
               ORDUdef09        NVARCHAR(10) NULL,     
               BillToKey        NVARCHAR(250) NULL,      
               SalesMan         NVARCHAR(70) NULL,      
               ExternOrderkey   NVARCHAR(30)  NULL,    
               ORDUdef04        NVARCHAR(20) NULL,    
               SDescr           NVARCHAR(150)NULL,    
               Style            NVARCHAR(20) NULL,    
               color            NVARCHAR(10) NULL,    
               stylecolor       NVARCHAR(31) NULL,     
               UnitPrice        FLOAT,    
             --  PQty             INT,    
               ExtendedPrice    INT,    
               TDATE             DATETIME,    
           --    SSize            NVARCHAR(5)  NULL,    
               SkuSize1         NVARCHAR(5)  NULL,    
               SkuSize2         NVARCHAR(5)  NULL,    
               SkuSize3         NVARCHAR(5)  NULL,    
               SkuSize4         NVARCHAR(5)  NULL,    
               SkuSize5         NVARCHAR(5)  NULL,    
               SkuSize6         NVARCHAR(5)  NULL,    
               SkuSize7         NVARCHAR(5)  NULL,    
               SkuSize8         NVARCHAR(5)  NULL,    
               SkuSize9         NVARCHAR(5)  NULL,    
               SkuSize10        NVARCHAR(5)  NULL,    
               SkuSize11        NVARCHAR(5)  NULL,    
               SkuSize12        NVARCHAR(5)  NULL,    
               SkuSize13        NVARCHAR(5)  NULL,    
               SkuSize14        NVARCHAR(5)  NULL,    
               SkuSize15        NVARCHAR(5)  NULL,    
               SkuSize16        NVARCHAR(5)  NULL,    
               SkuSize17        NVARCHAR(5)  NULL,    
               SkuSize18        NVARCHAR(5)  NULL,    
               SkuSize19        NVARCHAR(5)  NULL,    
               SkuSize20        NVARCHAR(5)  NULL,    
               SkuSize21        NVARCHAR(5)  NULL,    
               SkuSize22        NVARCHAR(5)  NULL,    
               SkuSize23        NVARCHAR(5)  NULL,    
               SkuSize24        NVARCHAR(5)  NULL,    
               Qty1             int      NULL,    
               Qty2             int      NULL,    
               Qty3             int      NULL,    
               Qty4             int      NULL,    
               Qty5             int      NULL,    
               Qty6             int      NULL,    
               Qty7             int      NULL,    
               Qty8             int      NULL,    
               Qty9             int      NULL,    
               Qty10            int      NULL,    
               Qty11            int      NULL,    
               Qty12            int      NULL,    
               Qty13            int      NULL,    
               Qty14            int      NULL,    
               Qty15            int      NULL,    
               Qty16            int      NULL,    
               Qty17            int      NULL,    
               Qty18            int      NULL,    
               Qty19            int      NULL,    
               Qty20            int      NULL,    
               Qty21            int      NULL,    
               Qty22            int      NULL,    
               Qty23            int      NULL,    
               Qty24            int      NULL,    
               pickheaderkey    NVARCHAR(20) NULL)          --(CS01)    
    
    
    
    
   CREATE TABLE #SkuSZ    
          ( Rowid     INT IDENTITY(1,1)     
          , Orderkey    NVARCHAR(10)   NULL    
          , Storerkey   NVARCHAR(15)   NULL    
          , Style       NVARCHAR(20)   NULL    
          , color       NVARCHAR(10)   NULL    
          , SSize1      NVARCHAR(5)    NULL    
          , SSize2      NVARCHAR(5)    NULL    
          , SSize3      NVARCHAR(5)    NULL    
          , SSize4      NVARCHAR(5)    NULL    
          , SSize5      NVARCHAR(5)    NULL    
          , SSize6      NVARCHAR(5)    NULL    
          , SSize7      NVARCHAR(5)    NULL    
          , SSize8      NVARCHAR(5)    NULL    
          , SSize9      NVARCHAR(5)    NULL    
          , SSize10     NVARCHAR(5)    NULL    
          , SSize11     NVARCHAR(5)    NULL    
          , SSize12     NVARCHAR(5)    NULL    
          , SSize13     NVARCHAR(5)    NULL    
          , SSize14     NVARCHAR(5)    NULL    
          , SSize15     NVARCHAR(5)    NULL    
          , SSize16     NVARCHAR(5)    NULL    
          , SSize17     NVARCHAR(5)    NULL    
          , SSize18     NVARCHAR(5)    NULL    
          , SSize19     NVARCHAR(5)    NULL    
          , SSize20     NVARCHAR(5)    NULL    
          , SSize21     NVARCHAR(5)    NULL    
          , SSize22     NVARCHAR(5)    NULL    
          , SSize23     NVARCHAR(5)    NULL    
          , SSize24     NVARCHAR(5)    NULL    
          )    
   CREATE INDEX #SkuSZ_IDXKey ON #SkuSZ(Orderkey, Storerkey, Style,color)    
     
   CREATE TABLE #TempSKU ( Storerkey   NVARCHAR(15)   NULL    
                     , Orderkey    NVARCHAR(10)   NULL     
                         , Style       NVARCHAR(20)   NULL    
                         , color       NVARCHAR(10)   NULL    
                         , SizeList    NVARCHAR(MAX)  NULL    
    )    
    
  -- SELECT @c_TempFloor = '', @c_TempOrderKey = '',     
   SELECT @n_Count = 0    
   SELECT @c_PreSkuSize = ''    
   SELECT @c_SkuSize1='',  @c_SkuSize2='',  @c_SkuSize3='',  @c_SkuSize4=''    
   SELECT @c_SkuSize5='',  @c_SkuSize6='',  @c_SkuSize7='',  @c_SkuSize8=''    
   SELECT @c_SkuSize9='',  @c_SkuSize10='', @c_SkuSize11='', @c_SkuSize12=''    
   SELECT @c_SkuSize13='', @c_SkuSize14='', @c_SkuSize15='', @c_SkuSize16=''    
   SELECT @c_SkuSize17='', @c_SkuSize18='', @c_SkuSize19='', @c_SkuSize20=''    
   SELECT @c_SkuSize21='', @c_SkuSize22='', @c_SkuSize23='', @c_SkuSize24=''    
   SET @c_PrevStyle  = ''    
   SET @c_PreColor = ''    
       
   SET @c_DelimiterSign = ','    
    
    
 SELECT DISTINCT OrderKey,loadkey    
   INTO #TempOrder    
   FROM  LOADPLANDETAIL (NOLOCK)    
   WHERE LOADPLANDETAIL.LoadKey = @c_LoadKey       
       
       
    DECLARE C_orderkey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
        SELECT DISTINCT OrderKey    
        FROM #TempOrder WITH (NOLOCK)    
        WHERE LoadKey = @c_LoadKey    
    
         OPEN C_orderkey    
         FETCH NEXT FROM C_orderkey INTO @c_TempOrderKey    
    
     WHILE (@@FETCH_STATUS=0)     
     BEGIN    
      --SELECT @c_TempOrderKey = MIN(OrderKey)    
      --FROM #TempOrder    
      --WHERE OrderKey > @c_TempOrderKey    
    
      --IF ISNULL(RTRIM(@c_TempOrderKey),'') = ''    
      --   BREAK    
             
      SET  @c_storerkey = ''    
      --SET  @c_Style = ''    
      --SET  @c_Color = ''     
      SET  @c_SizeList = ''    
          
      --SELECT DISTINCT     
      --       @c_storerkey = SKU.Storerkey    
      --      ,@c_Style  = ISNULL(SKU.Style,'')    
      --      ,@c_Color = ISNULL(SKU.Color,'')    
      --      ,@c_SizeList = ISNULL(RTRIM(RCFG.notes),'')       
          
      INSERT INTO #TempSKU    
      (    
       Storerkey,    
       Orderkey,    
       Style,    
       color,    
       SizeList    
      )    
        
      SELECT DISTINCT SKU.Storerkey AS Storerkey,    
              OH.OrderKey AS Orderkey,    
              ISNULL(SKU.Style,'') AS Style,    
              ISNULL(SKU.Color,'') AS Color,    
              ISNULL(RTRIM(RCFG.notes),'') AS SizeList    
     -- INTO #TempSKU            
      FROM ORDERS         OH   WITH (NOLOCK)    
      JOIN ORDERDETAIL    ODET   WITH (NOLOCK) ON (OH.Orderkey = ODET.Orderkey)    
      JOIN SKU            SKU  WITH (NOLOCK) ON (SKU.Storerkey = ODET.Storerkey AND SKU.SKU = ODET.SKU)    
      LEFT JOIN CODELKUP  RCFG WITH (NOLOCK) ON (RCFG.ListName = 'KSSIZECD')    
                                             AND(ISNULL(RTRIM(RCFG.Short),'') = ODET.UserDefine04)    
      WHERE OH.OrderKey = @c_TempOrderKey    
      AND OH.Loadkey = @c_LoadKey        
          
      DECLARE C_SKUList CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
      SELECT DISTINCT style,color,sizelist,storerkey    
      FROM #TempSKU    
      WHERE Orderkey = @c_TempOrderKey    
          
      OPEN C_SKUList    
      FETCH NEXT FROM C_SKUList INTO @c_GetStyle,@c_GetColor, @c_GetSizeList,@c_storerkey    
    
      WHILE (@@FETCH_STATUS=0)     
      BEGIN    
          
      DECLARE C_DelimSplit CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT SeqNo, ColValue     
         FROM dbo.fnc_DelimSplit(@c_DelimiterSign,@c_GetSizeList)    
    
         OPEN C_DelimSplit    
         FETCH NEXT FROM C_DelimSplit INTO @n_SeqNo, @c_ColValue    
    
        WHILE (@@FETCH_STATUS=0)     
        BEGIN    
             
          SELECT @n_Count = @n_Count + 1    
    
         IF @b_debug = 1    
         BEGIN    
            SELECT 'Count of sizes is ' + CONVERT(char(5), @n_rowid) + 'with size : ' + @c_SkuSize    
         END    
    
         SELECT @c_SkuSize1 = CASE @n_Count WHEN 1 THEN @c_ColValue    
                                 ELSE @c_SkuSize1    
                              END    
         SELECT @c_SkuSize2 = CASE @n_Count WHEN 2 THEN @c_ColValue    
                              ELSE @c_SkuSize2    
                              END    
         SELECT @c_SkuSize3 = CASE @n_Count WHEN 3 THEN @c_ColValue    
                              ELSE @c_SkuSize3    
                              END    
         SELECT @c_SkuSize4 = CASE @n_Count WHEN 4 THEN @c_ColValue    
                              ELSE @c_SkuSize4    
                              END    
         SELECT @c_SkuSize5 = CASE @n_Count WHEN 5 THEN @c_ColValue    
                              ELSE @c_SkuSize5    
                              END    
         SELECT @c_SkuSize6 = CASE @n_Count WHEN 6 THEN @c_ColValue    
                              ELSE @c_SkuSize6    
                              END    
         SELECT @c_SkuSize7 = CASE @n_Count WHEN 7 THEN @c_ColValue    
                              ELSE @c_SkuSize7    
                              END    
         SELECT @c_SkuSize8 = CASE @n_Count WHEN 8 THEN @c_ColValue    
                              ELSE @c_SkuSize8    
                              END    
         SELECT @c_SkuSize9 = CASE @n_Count WHEN 9 THEN @c_ColValue    
                              ELSE @c_SkuSize9    
        END    
         SELECT @c_SkuSize10 = CASE @n_Count WHEN 10 THEN @c_ColValue    
                               ELSE @c_SkuSize10    
                 END    
         SELECT @c_SkuSize11 = CASE @n_Count WHEN 11 THEN @c_ColValue    
                               ELSE @c_SkuSize11    
                               END    
         SELECT @c_SkuSize12 = CASE @n_Count WHEN 12 THEN @c_ColValue    
                               ELSE @c_SkuSize12    
                               END    
         SELECT @c_SkuSize13 = CASE @n_Count WHEN 13 THEN @c_ColValue    
                               ELSE @c_SkuSize13    
                               END    
         SELECT @c_SkuSize14 = CASE @n_Count WHEN 14 THEN @c_ColValue    
                               ELSE @c_SkuSize14    
                               END    
         SELECT @c_SkuSize15 = CASE @n_Count WHEN 15 THEN @c_ColValue    
                               ELSE @c_SkuSize15    
                               END    
         SELECT @c_SkuSize16 = CASE @n_Count WHEN 16 THEN @c_ColValue    
                               ELSE @c_SkuSize16    
                               END    
         SELECT @c_SkuSize17 = CASE @n_Count WHEN 17 THEN @c_ColValue    
                               ELSE @c_SkuSize17    
                               END    
         SELECT @c_SkuSize18 = CASE @n_Count WHEN 18 THEN @c_ColValue    
                               ELSE @c_SkuSize18    
                               END    
         SELECT @c_SkuSize19 = CASE @n_Count WHEN 19 THEN @c_ColValue    
                               ELSE @c_SkuSize19    
                               END    
         SELECT @c_SkuSize20 = CASE @n_Count WHEN 20 THEN @c_ColValue    
                               ELSE @c_SkuSize20    
                               END    
         SELECT @c_SkuSize21 = CASE @n_Count WHEN 21 THEN @c_ColValue    
                               ELSE @c_SkuSize21    
                               END    
         SELECT @c_SkuSize22 = CASE @n_Count WHEN 22 THEN @c_ColValue    
                               ELSE @c_SkuSize22    
                               END    
         SELECT @c_SkuSize23 = CASE @n_Count WHEN 23 THEN @c_ColValue    
                               ELSE @c_SkuSize23    
                               END    
         SELECT @c_SkuSize24 = CASE @n_Count WHEN 24 THEN @c_ColValue    
                               ELSE @c_SkuSize24    
                               END    
    
         IF @b_debug = 1    
         BEGIN    
            IF @c_TempOrderKey = '0000907514' -- checking any OrderKey    
            BEGIN    
               SELECT 'SkuSize is ' + @c_ColValue    
               SELECT 'Count of size' + CONVERT(char(5), @n_Count)    
               SELECT 'SkuSize1 to 24 is ' + @c_SkuSize1+','+ @c_SkuSize2+','+ @c_SkuSize3+','+ @c_SkuSize4+','+    
                     @c_SkuSize5+','+ @c_SkuSize6+','+ @c_SkuSize7+','+ @c_SkuSize8+','+    
                     @c_SkuSize9+','+ @c_SkuSize10+','+ @c_SkuSize11+','+ @c_SkuSize12+','+    
                     @c_SkuSize13+','+ @c_SkuSize14+','+ @c_SkuSize15+','+ @c_SkuSize16+','+    
                     @c_SkuSize17+','+ @c_SkuSize18+','+ @c_SkuSize19+','+ @c_SkuSize20+','+    
                     @c_SkuSize21+','+ @c_SkuSize22+','+ @c_SkuSize23+','+ @c_SkuSize24    
            END    
         END    
    -- SET @n_Count = @n_Count + 1    
    -- SET    
        
        -- SELECT @c_PrevOrderKey = @c_OrderKey    
         --ELECT @c_PrevFloor = @c_Floor    
             
         SELECT @c_PrevOrderKey = @c_getOrderkey    
         SET @c_PrevStyle = @c_GetStyle                                                               --(Wan01)     
         SET @c_PreColor = @c_GetColor     
    
         FETCH NEXT FROM C_DelimSplit INTO @n_SeqNo, @c_ColValue    
         END -- WHILE (@@FETCH_STATUS <> -1) AND @n_Continue <> 3    
    
         CLOSE C_DelimSplit    
         DEALLOCATE C_DelimSplit    
       --END      
           
          IF (@c_PrevOrderKey <> @c_OrderKey) OR     
            (@c_PrevStyle <> @c_GetStyle) OR                                                          --(Wan01)     
            (@c_PreColor <> @c_GetColor) OR                                                          --(Wan01)    
     (@@FETCH_STATUS = -1) -- last fetch    
     BEGIN    
         
           INSERT INTO #SKUSZ    
            (   Orderkey    
            ,   Storerkey    
            ,   Style    
            ,   color    
            ,   SSize1,SSize2,SSize3,SSize4,SSize5, SSize6, SSize7    
            ,   SSize8, SSize9, SSize10, SSize11, SSize12, SSize13    
            ,   SSize14, SSize15, SSize16, SSize17, SSize18,SSize19     
            ,   SSize20, SSize21, SSize22, SSize23, SSize24)     
           VALUES(@c_TempOrderKey,@c_storerkey,@c_GetStyle,@c_GetColor,@c_SkuSize1,     
                  @c_SkuSize2, @c_SkuSize3, @c_SkuSize4, @c_SkuSize5, @c_SkuSize6,    
                  @c_SkuSize7, @c_SkuSize8, @c_SkuSize9, @c_SkuSize10,@c_SkuSize11,    
                  @c_SkuSize12,@c_SkuSize13,@c_SkuSize14,@c_SkuSize15,@c_SkuSize16,    
                  @c_SkuSize17,@c_SkuSize18,@c_SkuSize19,@c_SkuSize20,@c_SkuSize21,    
                  @c_SkuSize22,@c_SkuSize23,@c_SkuSize24)    
         END    
         
         -- Reset counter and skusize    
            SELECT @n_Count = 0    
            SELECT @c_SkuSize1='',  @c_SkuSize2='',  @c_SkuSize3='',  @c_SkuSize4=''    
            SELECT @c_SkuSize5='',  @c_SkuSize6='',  @c_SkuSize7='',  @c_SkuSize8=''    
            SELECT @c_SkuSize9='',  @c_SkuSize10='', @c_SkuSize11='', @c_SkuSize12=''    
            SELECT @c_SkuSize13='', @c_SkuSize14='', @c_SkuSize15='', @c_SkuSize16=''    
            SELECT @c_SkuSize17='', @c_SkuSize18='', @c_SkuSize19='', @c_SkuSize20=''    
            SELECT @c_SkuSize21='', @c_SkuSize22='', @c_SkuSize23='', @c_SkuSize24=''    
         
       FETCH NEXT FROM C_SKUList INTO @c_GetStyle,@c_GetColor, @c_GetSizeList ,@c_storerkey                                   
      END    
          
       CLOSE C_SKUList    
       DEALLOCATE C_SKUList    
 --END                           
    
  --SELECT * FROM #SKUSZ           
  -- GOTO QUIT;               
      -- Get all unique sizes for the same order and same floor    
      -- tlting02 -CURSOR LOCAL    
      DECLARE pick_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT --ISNULL(RTRIM(SKUSZ.SIZE),'') SSize,      
                SKUSZ.Style,    
                SKUSZ.color,                                        
               SKUSZ.OrderKey    
        -- FROM ORDERS OH WITH (NOLOCK)     
       --  JOIN ORDERDETAIL ORDET WITH (NOLOCK) ON ORDET.OrderKey=OH.OrderKey    
       --  JOIN SKU S WITH (NOLOCK) on (S.SKU = ORDET.SKU AND S.Storerkey = ORDET.Storerkey)    
        -- JOIN #SKUSZ  SKUSZ WITH (NOLOCK) ON (OH.Orderkey = SKUSZ.Orderkey)                             
                                      --    AND(S.Storerkey = SKUSZ.Storerkey AND S.style = SKUSZ.style AND S.Color=SKUSZ.color)      
         FROM  #SKUSZ SKUSZ    
        -- WHERE OH.LoadKey = @c_LoadKey    
         where OrderKey = @c_TempOrderKey    
         --GROUP BY ISNULL(RTRIM(SKUSZ.SIZE),''),                                                                      
         --         OH.OrderKey    
--ORDER BY OH.OrderKey,                                              
         --         ISNULL(RTRIM(SKUSZ.SIZE),'')        
         ORDER BY rowid,SKUSZ.style,SKUSZ.color                                                          
                      
      OPEN pick_cur    
      FETCH NEXT FROM pick_cur INTO @c_GetStyle,@c_GetColor,@c_getOrderkey--@c_OrderKey                                                                                   
    
      WHILE (@@FETCH_STATUS <> -1)    
      BEGIN        
    
         IF @b_debug = 1    
         BEGIN    
            SELECT 'PrevOrderKey= ' + @c_PrevOrderKey + ', OrderKey= ' + @c_getOrderkey    
            SELECT '@c_PrevStyle= ' + @c_PrevStyle + ', Floor= ' + @c_GetStyle    
            SELECT '@c_PreColor= '  + @c_PreColor  +   ',Color = ' + @c_GetColor    
         END    
    
         --IF (@c_PrevOrderKey <> @c_OrderKey) OR    
         --   (@c_PrevOrderKey = @c_OrderKey AND @c_PrevFloor <> @c_Floor) OR    
         --   (@@FETCH_STATUS = -1) -- last fetch    
         --BEGIN    
       --   SELECT @c_PickSlipNo = NULL    
   --      IF (@c_PrevOrderKey <> @c_OrderKey) OR     
   --         (@c_PrevStyle <> @c_GetStyle) OR                                                          --(Wan01)     
   --         (@c_PreColor <> @c_GetColor) OR                                                          --(Wan01)    
   --  (@@FETCH_STATUS = -1) -- last fetch    
   --BEGIN    
            -- Insert into temp table    
                   
            INSERT INTO #TempPacklist08    
            SELECT STO.Company,    
                   ISNULL(c.long,'') AS logo,    
                   ORD.LoadKey,    
                   ORD.OrderKey,    
                   ORD.InvoiceNo,    
                   ORD.C_Company,    
                   ORD.B_VAT,    
                  (ORD.B_Address1+ORD.B_Address2+ORD.B_Address3) AS BAdd,    
                  (ORD.C_Address1 + ORD.C_Address2 + ORD.C_Address3) AS CAdd,    
                  ORD.Userdefine09,    
                  (ORD.BillToKey + SPACE(1) + ord.Userdefine02) AS BillToKey,    
                  (ORD.Salesman + SPACE(1) +(ORD.B_contact1 + ' ' + ORD.B_contact2)) AS Salesman,    
                  ORD.ExternOrderkey,    
                  ORD.Userdefine04,    
                  MAX(S.DESCR) AS Sdescr,    
                  S.Style,    
                  S.Color,    
                  (S.Style + '-' + S.Color) AS stylecolor,    
                  MAX(ODET.UnitPrice) AS UnitPrice,    
                  MAX(ODET.ExtendedPrice) AS ExtendPrice,ORD.Deliverydate,--GETDATE(),                --CS02
                  SKUSZ.SSize1, SKUSZ.SSize2, SKUSZ.SSize3, SKUSZ.SSize4,    
                  SKUSZ.SSize5, SKUSZ.SSize6, SKUSZ.SSize7, SKUSZ.SSize8,    
                  SKUSZ.SSize9, SKUSZ.SSize10, SKUSZ.SSize11, SKUSZ.SSize12,    
                  SKUSZ.SSize13, SKUSZ.SSize14, SKUSZ.SSize15, SKUSZ.SSize16,    
                  SKUSZ.SSize17, SKUSZ.SSize18, SKUSZ.SSize19, SKUSZ.SSize20,    
                  SKUSZ.SSize21, SKUSZ.SSize22, SKUSZ.SSize23, SKUSZ.SSize24,    
                  CASE WHEN LTRIM(S.size)=SKUSZ.SSize1 AND ISNULL(SKUSZ.SSIZE1,'') <> ''     
                                 THEN SUM(ODET.QtyAllocated + ODET.QtyPicked + ShippedQty)     
                                 ELSE NULL   --WL01    
                                 END,    
                  CASE WHEN LTRIM(S.size)=SKUSZ.SSize2 AND ISNULL(SKUSZ.SSIZE2,'') <> ''     
                                 THEN SUM(ODET.QtyAllocated + ODET.QtyPicked + ShippedQty)     
                                 ELSE NULL   --WL01    
                                 END,    
                  CASE WHEN LTRIM(S.size)=SKUSZ.SSize3 AND ISNULL(SKUSZ.SSIZE3,'') <> ''     
                                 THEN SUM(ODET.QtyAllocated + ODET.QtyPicked + ShippedQty)     
                                 ELSE NULL   --WL01    
                                 END,    
                  CASE WHEN LTRIM(S.size)=SKUSZ.SSize4 AND  ISNULL(SKUSZ.SSIZE4,'') <> ''     
                                 THEN SUM(ODET.QtyAllocated + ODET.QtyPicked + ShippedQty)     
                                 ELSE NULL   --WL01    
                                 END,    
                  CASE WHEN LTRIM(S.size)=SKUSZ.SSize5 AND ISNULL(SKUSZ.SSIZE5,'') <> ''     
                                 THEN SUM(ODET.QtyAllocated + ODET.QtyPicked + ShippedQty)     
                                 ELSE NULL   --WL01    
                                 END,    
                  CASE WHEN LTRIM(S.size)=SKUSZ.SSize6 AND ISNULL(SKUSZ.SSIZE6,'') <> ''     
                                 THEN SUM(ODET.QtyAllocated + ODET.QtyPicked + ShippedQty)     
                                 ELSE NULL   --WL01    
                                 END,    
                  CASE WHEN LTRIM(S.size)=SKUSZ.SSize7 AND ISNULL(SKUSZ.SSIZE7,'') <> ''     
                                 THEN SUM(ODET.QtyAllocated + ODET.QtyPicked + ShippedQty)     
                                 ELSE NULL   --WL01    
                                 END,    
                  CASE WHEN LTRIM(S.size)=SKUSZ.SSize8 AND ISNULL(SKUSZ.SSIZE8,'') <> ''     
                                 THEN SUM(ODET.QtyAllocated + ODET.QtyPicked + ShippedQty)     
                                 ELSE NULL   --WL01    
                      END,    
                  CASE WHEN LTRIM(S.size)=SKUSZ.SSize9 AND ISNULL(SKUSZ.SSIZE9,'') <> ''     
                      THEN SUM(ODET.QtyAllocated + ODET.QtyPicked + ShippedQty)     
                                 ELSE NULL   --WL01    
                                 END,    
                  CASE WHEN LTRIM(S.size)=SKUSZ.SSize10 AND ISNULL(SKUSZ.SSIZE10,'') <> ''     
                                 THEN SUM(ODET.QtyAllocated + ODET.QtyPicked + ShippedQty)     
                                 ELSE NULL   --WL01    
                                 END,    
                  CASE WHEN LTRIM(S.size)=SKUSZ.SSize11 AND ISNULL(SKUSZ.SSIZE11,'') <> ''     
                                 THEN SUM(ODET.QtyAllocated + ODET.QtyPicked + ShippedQty)     
                                 ELSE NULL   --WL01    
                                 END,    
                  CASE WHEN LTRIM(S.size)=SKUSZ.SSize12 AND ISNULL(SKUSZ.SSIZE12,'') <> ''     
                                 THEN SUM(ODET.QtyAllocated + ODET.QtyPicked + ShippedQty)     
                                 ELSE NULL   --WL01    
                                 END,    
                  CASE WHEN LTRIM(S.size)=SKUSZ.SSize13 AND ISNULL(SKUSZ.SSIZE13,'') <> ''     
                                 THEN SUM(ODET.QtyAllocated + ODET.QtyPicked + ShippedQty)     
                                 ELSE NULL   --WL01    
                                 END,    
                  CASE WHEN LTRIM(S.size)=SKUSZ.SSize14 AND ISNULL(SKUSZ.SSIZE14,'') <> ''     
                                 THEN SUM(ODET.QtyAllocated + ODET.QtyPicked + ShippedQty)     
                                 ELSE NULL   --WL01    
                                 END,    
                  CASE WHEN LTRIM(S.size)=SKUSZ.SSize15 AND ISNULL(SKUSZ.SSIZE15,'') <> ''     
                                 THEN SUM(ODET.QtyAllocated + ODET.QtyPicked + ShippedQty)     
                                 ELSE NULL   --WL01    
                                 END,    
                  CASE WHEN LTRIM(S.size)=SKUSZ.SSize16 AND ISNULL(SKUSZ.SSIZE16,'') <> ''     
                                 THEN SUM(ODET.QtyAllocated + ODET.QtyPicked + ShippedQty)     
                                 ELSE NULL   --WL01    
                                 END,      
                  CASE WHEN LTRIM(S.size)=SKUSZ.SSize17 AND ISNULL(SKUSZ.SSIZE17,'') <> ''     
                                 THEN SUM(ODET.QtyAllocated + ODET.QtyPicked + ShippedQty)     
                                 ELSE NULL   --WL01    
                                 END,    
                  CASE WHEN LTRIM(S.size)=SKUSZ.SSize18 AND ISNULL(SKUSZ.SSIZE18,'') <> ''     
                                 THEN SUM(ODET.QtyAllocated + ODET.QtyPicked + ShippedQty)     
                                 ELSE NULL   --WL01    
                                 END,    
                  CASE WHEN LTRIM(S.size)=SKUSZ.SSize19 AND ISNULL(SKUSZ.SSIZE19,'') <> ''     
                                 THEN SUM(ODET.QtyAllocated + ODET.QtyPicked + ShippedQty)     
                                 ELSE NULL   --WL01    
                                 END,    
                  CASE WHEN LTRIM(S.size)=SKUSZ.SSize20 AND ISNULL(SKUSZ.SSIZE20,'') <> ''     
                                 THEN SUM(ODET.QtyAllocated + ODET.QtyPicked + ShippedQty)     
                                 ELSE NULL   --WL01    
                                 END,    
                  CASE WHEN LTRIM(S.size)=SKUSZ.SSize21 AND ISNULL(SKUSZ.SSIZE21,'') <> ''     
                                 THEN SUM(ODET.QtyAllocated + ODET.QtyPicked + ShippedQty)     
                                 ELSE NULL   --WL01    
                                 END,    
                  CASE WHEN LTRIM(S.size)=SKUSZ.SSize22 AND ISNULL(SKUSZ.SSIZE22,'') <> ''     
                                 THEN SUM(ODET.QtyAllocated + ODET.QtyPicked + ShippedQty)     
                                 ELSE NULL   --WL01    
                                 END,    
                  CASE WHEN LTRIM(S.size)=SKUSZ.SSize23 AND ISNULL(SKUSZ.SSIZE23,'') <> ''     
                                 THEN SUM(ODET.QtyAllocated + ODET.QtyPicked + ShippedQty)     
                                 ELSE NULL   --WL01    
                                 END,    
                  CASE WHEN LTRIM(S.size)=SKUSZ.SSize24 AND ISNULL(SKUSZ.SSIZE24,'') <> ''     
                                 THEN SUM(ODET.QtyAllocated + ODET.QtyPicked + ShippedQty)     
                                 ELSE NULL   --WL01    
                        END    
              ,PH.PickHeaderKey                              --(CS01)        
            FROM ORDERS ORD (NOLOCK)    
            JOIN Orderdetail ODET (NOLOCK) ON ORD.OrderKey=ODET.OrderKey   
            JOIN Storer STO WITH (NOLOCK) ON STO.StorerKey=ORD.StorerKey AND STO.[type]='1'    
            LEFT JOIN CODELKUP AS c WITH (NOLOCK) ON c.LISTNAME='KSCOMPANY' AND c.Code=ORD.OrderGroup    
            JOIN SKU S WITH (NOLOCK) ON S.StorerKey=ODET.StorerKey AND S.Sku = ODET.Sku    
            LEFT JOIN #SKUSZ  SKUSZ WITH (NOLOCK) ON (ORD.Orderkey = SKUSZ.Orderkey)                         
                                             AND(S.Storerkey = SKUSZ.Storerkey AND S.style = SKUSZ.style     
                                             AND S.color = SKUSZ.color)      
           --CS01 Start    
           JOIN PICKHEADER PH WITH (NOLOCK) ON ph.OrderKey=ORD.OrderKey    
           --CS01 End                                       
            --JOIN LOC WITH (NOLOCK) ON (LOC.LOC = PICKDETAIL.LOC)    
            WHERE ORD.LoadKey = @c_LoadKey    
            AND ORD.OrderKey = @c_TempOrderKey    
            AND   SKUSZ.Style = @c_GetStyle                                                           
            AND   SKUSZ.Color = @c_GetColor    
        /*    AND 1=CASE SKUSZ.SIZE WHEN @c_SkuSize1 THEN 1                                                       
                                  WHEN @c_SkuSize2 THEN 1    
                                  WHEN @c_SkuSize3 THEN 1    
                                  WHEN @c_SkuSize4 THEN 1    
                                  WHEN @c_SkuSize5 THEN 1    
                                  WHEN @c_SkuSize6 THEN 1    
                                  WHEN @c_SkuSize7 THEN 1    
                                  WHEN @c_SkuSize8 THEN 1    
                                  WHEN @c_SkuSize9 THEN 1    
                                  WHEN @c_SkuSize10 THEN 1    
                                  WHEN @c_SkuSize11 THEN 1    
                                  WHEN @c_SkuSize12 THEN 1    
                                  WHEN @c_SkuSize13 THEN 1    
                                  WHEN @c_SkuSize14 THEN 1    
                                  WHEN @c_SkuSize15 THEN 1    
                                  WHEN @c_SkuSize16 THEN 1    
                                  WHEN @c_SkuSize17 THEN 1    
                                  WHEN @c_SkuSize18 THEN 1    
                                  WHEN @c_SkuSize19 THEN 1    
                                  WHEN @c_SkuSize20 THEN 1    
                                  WHEN @c_SkuSize21 THEN 1    
                                  WHEN @c_SkuSize22 THEN 1    
                                  WHEN @c_SkuSize23 THEN 1    
                                  WHEN @c_SkuSize24 THEN 1    
                    ELSE 0    
                    END*/    
            GROUP BY  STO.Company,    
                      ISNULL(c.long,'') ,    
                      ORD.LoadKey,    
                      ORD.OrderKey,    
                      ORD.InvoiceNo,    
                      ORD.C_Company,    
                      ORD.B_VAT,    
                     (ORD.B_Address1+ORD.B_Address2+ORD.B_Address3) ,    
                     (ORD.C_Address1 + ORD.C_Address2 + ORD.C_Address3) ,    
                     ORD.Userdefine09,    
                     (ORD.BillToKey + SPACE(1) + ord.Userdefine02) ,    
                     (ORD.Salesman + SPACE(1) +(ORD.B_contact1 + ' ' + ORD.B_contact2)) ,    
                     ORD.ExternOrderkey,    
                     ORD.Userdefine04,    
                     S.Style,    
                     S.Color, SKUSZ.SSize1, SKUSZ.SSize2, SKUSZ.SSize3, SKUSZ.SSize4,    
                     SKUSZ.SSize5, SKUSZ.SSize6, SKUSZ.SSize7, SKUSZ.SSize8,    
                     SKUSZ.SSize9, SKUSZ.SSize10, SKUSZ.SSize11, SKUSZ.SSize12,    
             SKUSZ.SSize13, SKUSZ.SSize14, SKUSZ.SSize15, SKUSZ.SSize16,    
                     SKUSZ.SSize17, SKUSZ.SSize18, SKUSZ.SSize19, SKUSZ.SSize20,    
                     SKUSZ.SSize21, SKUSZ.SSize22, SKUSZ.SSize23, SKUSZ.SSize24,S.[Size]    
                     ,PH.PickHeaderKey, ORD.Deliverydate              --(CS01)   --(CS02) 
            ORDER BY ORD.Userdefine04,    
                     S.Style,    
                     S.color,    
                     Size    
                         
                     
                 --SELECT * FROM    #TempPacklist08     
           
          FETCH NEXT FROM pick_cur INTO @c_GetStyle,@c_GetColor,@c_getOrderkey--@c_OrderKey      
         --END    
        END    
        CLOSE pick_cur    
        DEALLOCATE pick_cur    
             
    FETCH NEXT FROM C_orderkey INTO @c_TempOrderKey    
   END -- WHILE (@@FETCH_STATUS <> -1) AND @n_Continue <> 3    
    
   CLOSE C_orderkey    
   DEALLOCATE C_orderkey    
    
 --IF @c_DWCategory = 'H'    
 --BEGIN    
 
   --WL01 - S
   SELECT StyleColor
        , ISNULL(SUM(Qty1),0)  + ISNULL(SUM(Qty2),0)  + ISNULL(SUM(Qty3),0)  + ISNULL(SUM(Qty4),0)  + ISNULL(SUM(Qty5),0)  + ISNULL(SUM(Qty6),0)  +   
          ISNULL(SUM(Qty7),0)  + ISNULL(SUM(Qty8),0)  + ISNULL(SUM(Qty9),0)  + ISNULL(SUM(Qty10),0) + ISNULL(SUM(Qty11),0) + ISNULL(SUM(Qty12),0) +    
          ISNULL(SUM(Qty13),0) + ISNULL(SUM(Qty14),0) + ISNULL(SUM(Qty15),0) + ISNULL(SUM(Qty16),0) +     
          ISNULL(SUM(Qty17),0) + ISNULL(SUM(Qty18),0) + ISNULL(SUM(Qty19),0) + ISNULL(SUM(Qty20),0) + ISNULL(SUM(Qty21),0) + ISNULL(SUM(Qty22),0) +  
          ISNULL(SUM(Qty23),0) + ISNULL(SUM(Qty24),0) AS TotalQty, Pickheaderkey, UnitPrice, ExtendedPrice   --WL02
   INTO #TempPacklist08_Qty
   FROM #TempPacklist08
   GROUP BY StyleColor, Pickheaderkey, UnitPrice, ExtendedPrice   --WL02
   
   --SELECT * FROM #TempPacklist08_Qty
   --WL01 - E
   
   SELECT STOCompany,CLogo,Loadkey,OrderKey,InvoiceNo,CCompany,    
          B_Vat,BAddress,CAddress,ORDUdef09,BillToKey,SalesMan,    
          ExternOrderkey,ORDUdef04,SDescr,Style,color,#TempPacklist08.StyleColor,#TempPacklist08.UnitPrice,   --WL01   --WL02 
          #TempPacklist08.ExtendedPrice,TDate,    --WL02
          SkuSize1, SkuSize2, SkuSize3, SkuSize4, SkuSize5, SkuSize6, SkuSize7, SkuSize8,    
          SkuSize9, SkuSize10, SkuSize11, SkuSize12, SkuSize13, SkuSize14, SkuSize15, SkuSize16,    
          SkuSize17, SkuSize18, SkuSize19, SkuSize20, SkuSize21, SkuSize22, SkuSize23, SkuSize24,    
         SUM(Qty1) Qty1, SUM(Qty2) Qty2, SUM(Qty3) Qty3, SUM(Qty4) Qty4, SUM(Qty5) Qty5, SUM(Qty6) Qty6,    
         SUM(Qty7) Qty7, SUM(Qty8) Qty8, SUM(Qty9) Qty9, SUM(Qty10) Qty10, SUM(Qty11) Qty11, SUM(Qty12) Qty12,    
         SUM(Qty13) Qty13, SUM(Qty14) Qty14, SUM(Qty15) Qty15, SUM(Qty16) Qty16,    
         SUM(Qty17) Qty17, SUM(Qty18) Qty18, SUM(Qty19) Qty19, SUM(Qty20) Qty20, SUM(Qty21) Qty21, SUM(Qty22) Qty22,    
         SUM(Qty23) Qty23, SUM(Qty24) Qty24,#TempPacklist08.Pickheaderkey,Q.TotalQty              --(CS01)   --WL01    
      FROM #TempPacklist08 WITH (NOLOCK) 
      JOIN #TempPacklist08_Qty Q (NOLOCK) ON Q.StyleColor = #TempPacklist08.StyleColor AND Q.Pickheaderkey = #TempPacklist08.Pickheaderkey --WL01
                                         AND #TempPacklist08.UnitPrice = Q.UnitPrice AND Q.ExtendedPrice = #TempPacklist08.ExtendedPrice   --WL02
      GROUP BY STOCompany,CLogo,Loadkey,OrderKey,InvoiceNo,CCompany,    
            B_Vat,BAddress,CAddress,ORDUdef09,BillToKey,SalesMan,    
            ExternOrderkey,ORDUdef04,Style,color,SDescr,#TempPacklist08.StyleColor,#TempPacklist08.UnitPrice,   --WL01    
            #TempPacklist08.ExtendedPrice,TDate, SkuSize1, SkuSize2, SkuSize3, SkuSize4, SkuSize5, SkuSize6, SkuSize7, SkuSize8,   --WL02   
            SkuSize9, SkuSize10, SkuSize11, SkuSize12, SkuSize13, SkuSize14, SkuSize15, SkuSize16,    
            SkuSize17, SkuSize18, SkuSize19, SkuSize20, SkuSize21, SkuSize22, SkuSize23, SkuSize24     
            ,#TempPacklist08.Pickheaderkey,Q.TotalQty              --(CS01)   --WL01    
   ORDER BY ExternOrderkey,ORDUdef04,Style,color    --JyhBin
 --END    
-- ELSE    
 --BEGIN     
   --SELECT     
  -- FROM #TempPacklist08 WITH (NOLOCK)    
  -- WHERE Style = @c_style    
  -- AND color = @c_color    
  -- GROUP BY Style,color,    
  --          SkuSize1, SkuSize2, SkuSize3, SkuSize4, SkuSize5, SkuSize6, SkuSize7, SkuSize8,    
  --          SkuSize9, SkuSize10, SkuSize11, SkuSize12, SkuSize13, SkuSize14, SkuSize15, SkuSize16,    
  --          SkuSize17, SkuSize18, SkuSize19, SkuSize20, SkuSize21, SkuSize22, SkuSize23, SkuSize24    
  --END              
QUIT:  
   --WL01 - S  
   --DROP TABLE #TempOrder    
   --DROP TABLE #TempPacklist08    
   --DROP TABLE #TempSKU
 
   IF OBJECT_ID('tempdb..#TempOrder') IS NOT NULL
      DROP TABLE #TempOrder
   IF OBJECT_ID('tempdb..#TempPacklist08') IS NOT NULL
      DROP TABLE #TempPacklist08
   IF OBJECT_ID('tempdb..#TempSKU') IS NOT NULL
      DROP TABLE #TempSKU
   IF OBJECT_ID('tempdb..#TempPacklist08_Qty') IS NOT NULL
      DROP TABLE #TempPacklist08_Qty
   --WL01 - E
END    

GO