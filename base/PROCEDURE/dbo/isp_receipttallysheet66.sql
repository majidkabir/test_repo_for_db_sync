SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: isp_ReceiptTallySheet66                             */
/* Creation Date: 2020-02-24                                            */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-12154 - [TW] SKX - TALLYSHT - RCMReport                 */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0 (Unicode)                                          */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[isp_ReceiptTallySheet66] (
                  @c_ReceiptKeyStart NVARCHAR(10),
                  @c_ReceiptKeyEnd   NVARCHAR(10),
                  @c_StorerkeyStart  NVARCHAR(15),
                  @c_StorerkeyEnd    NVARCHAR(15),
                  @c_UserID          NVARCHAR(50) = '' )
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_ReceiptKey          NVARCHAR(10),
           @c_BuyerPO             NVARCHAR(20),
           @c_OrderGroup          NVARCHAR(10),
           @c_ExternOrderKey      NVARCHAR(50),  --tlting_ext
           @c_Route               NVARCHAR(10),
           @c_Notes               NVARCHAR(255),
           @d_OrderDate           datetime,
           @c_ConsigneeKey        NVARCHAR(15),
           @c_Company             NVARCHAR(45),
           @d_DeliveryDate        datetime,
           @c_Notes2              NVARCHAR(255),
           @c_Loc                 NVARCHAR(10),
           @c_Sku                 NVARCHAR(20),
           @c_PrevSKU             NVARCHAR(20),
           @c_UOM                 NVARCHAR(10),
           @c_SkuSize             NVARCHAR(5),
           @n_Qty                 int,
           @c_Floor               NVARCHAR(1),
           @c_TempReceiptKey        NVARCHAR(10),
           @c_TempFloor           NVARCHAR(1),
           @c_TempSize            NVARCHAR(5),
           @n_TempQty             int,
           @c_PrevReceiptkey      NVARCHAR(10),
           @c_PrevFloor           NVARCHAR(1),
           @b_success             int,
           @n_err                 int,
           @c_errmsg              NVARCHAR(255),
           @n_Count               int,
           @c_Column              NVARCHAR(10),
           @c_SkuSize1            NVARCHAR(5),
           @c_SkuSize2            NVARCHAR(5),
           @c_SkuSize3            NVARCHAR(5),
           @c_SkuSize4            NVARCHAR(5),
           @c_SkuSize5            NVARCHAR(5),
           @c_SkuSize6            NVARCHAR(5),
           @c_SkuSize7            NVARCHAR(5),
           @c_SkuSize8            NVARCHAR(5),
           @c_SkuSize9            NVARCHAR(5),
           @c_SkuSize10           NVARCHAR(5),
           @c_SkuSize11           NVARCHAR(5),
           @c_SkuSize12           NVARCHAR(5),
           @c_SkuSize13           NVARCHAR(5),
           @c_SkuSize14           NVARCHAR(5),
           @c_SkuSize15           NVARCHAR(5),
           @c_SkuSize16           NVARCHAR(5),
           @c_SkuSize17           NVARCHAR(5),
           @c_SkuSize18           NVARCHAR(5),
           @c_SkuSize19           NVARCHAR(5),
           @c_SkuSize20           NVARCHAR(5),
           @c_SkuSize21           NVARCHAR(5),
           @c_SkuSize22           NVARCHAR(5),
           @c_SkuSize23           NVARCHAR(5),
           @c_SkuSize24           NVARCHAR(5),
           @c_SkuSize25           NVARCHAR(5),
           @c_SkuSize26           NVARCHAR(5),
           @c_SkuSize27           NVARCHAR(5),
           @c_SkuSize28           NVARCHAR(5),
           @c_SkuSize29           NVARCHAR(5),
           @c_SkuSize30           NVARCHAR(5),
           @c_SkuSize31           NVARCHAR(5),
           @c_SkuSize32           NVARCHAR(5),
           @n_Qty1                int,
           @n_Qty2                int,
           @n_Qty3                int,
           @n_Qty4                int,
           @n_Qty5                int,
           @n_Qty6                int,
           @n_Qty7                int,
           @n_Qty8                int,
           @n_Qty9                int,
           @n_Qty10               int,
           @n_Qty11               int,
           @n_Qty12               int,
           @n_Qty13               int,
           @n_Qty14               int,
           @n_Qty15               int,
           @n_Qty16               int,
           @n_Qty17               int,
           @n_Qty18               int,
           @n_Qty19               int,
           @n_Qty20               int,
           @n_Qty21               int,
           @n_Qty22               int,
           @n_Qty23               int,
           @n_Qty24               int,
           @n_Qty25               int,
           @n_Qty26               int,
           @n_Qty27               int,
           @n_Qty28               int,
           @n_Qty29               int,
           @n_Qty30               int,
           @n_Qty31               int,
           @n_Qty32               int,
           @c_Bin                 NVARCHAR(2),
           @C_BUSR6               NVARCHAR(30),
           @c_LogicalLocation     NVARCHAR(18),    -- GOH01
           @c_Sort                NVARCHAR(5),    --(Wan01)
           @c_Pickzone            NVARCHAR(20),
           @c_StyleColor          NVARCHAR(30),
           @c_PrevStyleColor      NVARCHAR(30),
           @n_MaxLine             INT = 3,
           @c_UserDefine03        NVARCHAR(10),
           @c_PrevUserDefine03    NVARCHAR(10)

   DECLARE @b_debug int
   SELECT @b_debug = 0

   CREATE TABLE #TempReceipt (
               Receiptkey        NVARCHAR(10) NULL,  
               ContainerType     NVARCHAR(20) NULL,
               Containerkey      NVARCHAR(18) NULL,
               Facility          NVARCHAR(15) NULL,
               ExternReceiptkey  NVARCHAR(20) NULL,
               ContainerQty      INT          NULL,  
               ReceiptDate       DATETIME     NULL,
               StyleColor        NVARCHAR(30) NULL, 
               UserDefine03      NVARCHAR(30) NULL,
               Casecnt           INT          NULL,
               SKUDescr          NVARCHAR(60) NULL,
               QtyExpected       INT          NULL, 
               --CaseExpected      INT          NULL,
               --UserDefine02      INT          NULL,
               SkuSize1          NVARCHAR(5)  NULL,
               SkuSize2          NVARCHAR(5)  NULL,
               SkuSize3          NVARCHAR(5)  NULL,
               SkuSize4          NVARCHAR(5)  NULL,
               SkuSize5          NVARCHAR(5)  NULL,
               SkuSize6          NVARCHAR(5)  NULL,
               SkuSize7          NVARCHAR(5)  NULL,
               SkuSize8          NVARCHAR(5)  NULL,
               SkuSize9          NVARCHAR(5)  NULL,
               SkuSize10         NVARCHAR(5)  NULL,
               SkuSize11         NVARCHAR(5)  NULL,
               SkuSize12         NVARCHAR(5)  NULL,
               SkuSize13         NVARCHAR(5)  NULL,
               SkuSize14         NVARCHAR(5)  NULL,
               SkuSize15         NVARCHAR(5)  NULL,
               SkuSize16         NVARCHAR(5)  NULL,
               SkuSize17         NVARCHAR(5)  NULL,
               SkuSize18         NVARCHAR(5)  NULL,
               SkuSize19         NVARCHAR(5)  NULL,
               SkuSize20         NVARCHAR(5)  NULL,
               SkuSize21         NVARCHAR(5)  NULL,
               SkuSize22         NVARCHAR(5)  NULL,
               SkuSize23         NVARCHAR(5)  NULL,
               SkuSize24         NVARCHAR(5)  NULL,
               SkuSize25         NVARCHAR(5)  NULL,
               SkuSize26         NVARCHAR(5)  NULL,
               SkuSize27         NVARCHAR(5)  NULL,
               SkuSize28         NVARCHAR(5)  NULL,
               SkuSize29         NVARCHAR(5)  NULL,
               SkuSize30         NVARCHAR(5)  NULL,
               SkuSize31         NVARCHAR(5)  NULL,
               SkuSize32         NVARCHAR(5)  NULL,
               Qty1              int          NULL,
               Qty2              int          NULL,
               Qty3              int          NULL,
               Qty4              int          NULL,
               Qty5              int          NULL,
               Qty6              int          NULL,
               Qty7              int          NULL,
               Qty8              int          NULL,
               Qty9              int          NULL,
               Qty10             int          NULL,
               Qty11             int          NULL,
               Qty12             int          NULL,
               Qty13             int          NULL,
               Qty14             int          NULL,
               Qty15             int          NULL,
               Qty16             int          NULL,
               Qty17             int          NULL,
               Qty18             int          NULL,
               Qty19             int          NULL,
               Qty20             int          NULL,
               Qty21             int          NULL,
               Qty22             int          NULL,
               Qty23             int          NULL,
               Qty24             int          NULL,
               Qty25             int          NULL,
               Qty26             int          NULL,
               Qty27             int          NULL,
               Qty28             int          NULL,
               Qty29             int          NULL,
               Qty30             int          NULL,
               Qty31             int          NULL,
               Qty32             int          NULL,
               Logo              NVARCHAR(50) NULL,
               RECType           NVARCHAR(20) NULL
               --Sizesort          INT          NULL,
               ) 

   CREATE TABLE #TEMPUSERDEFINE02 (
            Receiptkey   NVARCHAR(10) NULL
          , SKU          NVARCHAR(30) NULL
          , Storerkey    NVARCHAR(15) NULL
          , UserDefine02 INT NULL
          , UserDefine03 NVARCHAR(20) NULL )

   --(Wan03) - START
   CREATE TABLE #SkuSZ
          ( Receiptkey  NVARCHAR(10)   NULL
          , Storerkey   NVARCHAR(15)   NULL
          , Sku         NVARCHAR(20)   NULL
          , Size        NVARCHAR(5)    NULL
          , Qty         INT NULL
          , StyleColor  NVARCHAR(30)   NULL
          )
   CREATE INDEX #SkuSZ_IDXKey ON #SkuSZ(Receiptkey, Storerkey, Sku)
   --(Wan03) - END

   SELECT @c_TempFloor = '', @c_TempReceiptKey = '', @n_Count = 0
   SELECT @c_SkuSize1='',  @c_SkuSize2='',  @c_SkuSize3='',  @c_SkuSize4=''
   SELECT @c_SkuSize5='',  @c_SkuSize6='',  @c_SkuSize7='',  @c_SkuSize8=''
   SELECT @c_SkuSize9='',  @c_SkuSize10='', @c_SkuSize11='', @c_SkuSize12=''
   SELECT @c_SkuSize13='', @c_SkuSize14='', @c_SkuSize15='', @c_SkuSize16=''
   SELECT @c_SkuSize17='', @c_SkuSize18='', @c_SkuSize19='', @c_SkuSize20=''
   SELECT @c_SkuSize21='', @c_SkuSize22='', @c_SkuSize23='', @c_SkuSize24=''
   SELECT @c_SkuSize25='', @c_SkuSize26='', @c_SkuSize27='', @c_SkuSize28=''
   SELECT @c_SkuSize29='', @c_SkuSize30='', @c_SkuSize31='', @c_SkuSize32=''

   SET @c_Sort = ''                        

   SELECT DISTINCT R.Receiptkey AS Receiptkey
   INTO #TempReceiptKey
   FROM Receipt R WITH (NOLOCK)
   WHERE R.Receiptkey BETWEEN @c_ReceiptKeyStart AND @c_ReceiptKeyEnd   
     AND R.Storerkey BETWEEN @c_StorerkeyStart AND @c_StorerkeyEnd    
       
   WHILE (1 = 1)
   BEGIN
      SELECT @c_TempReceiptKey = MIN(Receiptkey)
      FROM #TempReceiptKey
      WHERE Receiptkey > @c_TempReceiptKey

      IF ISNULL(RTRIM(@c_TempReceiptKey),'') = ''
         BREAK
      
      ----NJOW02
      --DELETE #SizeSortByListName
      --INSERT INTO #SizeSortByListName
      --   SELECT SUBSTRING(PD.Loc, 2, 1)
      --   FROM PICKDETAIL PD (NOLOCK)
      --   JOIN LOTATTRIBUTE LA (NOLOCK) ON PD.Lot = LA.Lot
      --   WHERE PD.OrderKey = @c_TempReceiptKey
      --   AND LEFT(LA.Lottable01,2) IN('10','30')
      --   AND PD.Storerkey = 'CNV'
      --   GROUP BY SUBSTRING(PD.Loc, 2, 1)

      DELETE FROM #TEMPUSERDEFINE02

      INSERT INTO #TEMPUSERDEFINE02
      SELECT RECEIPTDETAIL.ReceiptKey, 
             RECEIPTDETAIL.SKU,
             RECEIPTDETAIL.Storerkey,
             CASE WHEN ISNUMERIC(RECEIPTDETAIL.UserDefine02) = 1 THEN CAST(RECEIPTDETAIL.UserDefine02 AS INT) ELSE 0 END,
             ISNULL(RECEIPTDETAIL.UserDefine03,'')
      FROM RECEIPTDETAIL WITH (NOLOCK)
      WHERE RECEIPTDETAIL.Receiptkey = @c_TempReceiptKey

      INSERT INTO #SKUSZ
            (   Receiptkey
            ,   Storerkey
            ,   Sku
            ,   Size
            ,   Qty
            ,   StyleColor
              )
      SELECT DISTINCT 
             R.Receiptkey
            ,S.Storerkey
            ,S.Sku
            ,Size = ISNULL(RTRIM(S.Size),'')  ,0
            --,CASE WHEN R.[RECType] = 'MIXPACK' THEN SUM(t.UserDefine02)
            --                                   ELSE (SELECT SUM(t.Qty) FROM #TEMPQTYEXPECTED t WHERE t.SKU = S.SKU AND t.Receiptkey = R.Receiptkey )  END
            ,ISNULL(RTRIM(S.Style),'') + ISNULL(RTRIM(S.Color),'') StyleColor
      FROM RECEIPT R WITH (NOLOCK)
      JOIN RECEIPTDETAIL RD WITH (NOLOCK) ON RD.Receiptkey = R.Receiptkey
      JOIN SKU S WITH (NOLOCK) ON S.Storerkey = RD.Storerkey AND S.SKU = RD.SKU
      --CROSS APPLY (SELECT SUM(UserDefine02) as UserDefine02 FROM #TEMPUSERDEFINE02 WHERE RECEIPTKEY = R.ReceiptKey AND SKU = RD.SKU) AS t
      WHERE R.Receiptkey = @c_TempReceiptKey
      GROUP BY R.Receiptkey
              ,S.Storerkey
              ,S.Sku
              ,ISNULL(RTRIM(S.Size),'')
              ,R.[RECType]
              ,ISNULL(RTRIM(S.Style),'') + ISNULL(RTRIM(S.Color),'')

      -- Get all unique sizes for the same order and same pickzone
      -- tlting02 -CURSOR LOCAL
      DECLARE pick_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT ISNULL(RTRIM(SKUSZ.SIZE),'') SSize, -- SOS# 239687                                       --(Wan03)
                RECEIPT.ReceiptKey,
                SizeSort = CASE WHEN ISNUMERIC(ISNULL(CL1.UDF05,'')) = 1 THEN CAST(ISNULL(CL1.UDF05,'') AS INT) ELSE 0 END,
                SKUSZ.StyleColor,
                RECEIPTDETAIL.USERDEFINE03
         FROM RECEIPT WITH (NOLOCK)
         JOIN RECEIPTDETAIL WITH (NOLOCK) on RECEIPT.Receiptkey = RECEIPTDETAIL.Receiptkey
         JOIN SKU WITH (NOLOCK) on (SKU.SKU = RECEIPTDETAIL.SKU AND SKU.Storerkey = RECEIPTDETAIL.Storerkey)
         JOIN #SKUSZ  SKUSZ WITH (NOLOCK) ON (Receipt.Receiptkey = SKUSZ.Receiptkey)                          --(Wan03)
                                          AND(SKU.Storerkey = SKUSZ.Storerkey AND SKU.SKU = SKUSZ.SKU)   --(Wan03)
         LEFT JOIN CODELKUP  CL1 WITH (NOLOCK) ON (CL1.ListName = 'SKXSIZE')
                                               AND(CL1.Code = SKUSZ.Size)                                       
                                               AND(CL1.Storerkey= SKU.Storerkey)
         WHERE RECEIPT.ReceiptKey = @c_TempReceiptKey
         GROUP BY ISNULL(RTRIM(SKUSZ.SIZE),''),                                                          --(Wan03)         
                  RECEIPT.ReceiptKey,                                                                                                                  
                  CASE WHEN ISNUMERIC(ISNULL(CL1.UDF05,'')) = 1 THEN CAST(ISNULL(CL1.UDF05,'') AS INT) ELSE 0 END,
                  SKUSZ.StyleColor, RECEIPTDETAIL.USERDEFINE03
         ORDER BY RECEIPT.ReceiptKey, RECEIPTDETAIL.USERDEFINE03, SKUSZ.StyleColor, SizeSort

      OPEN pick_cur
      FETCH NEXT FROM pick_cur INTO @c_SkuSize, @c_Receiptkey, @c_Sort, @c_StyleColor, @c_UserDefine03                                                    

      WHILE (@@FETCH_STATUS <> -1)
      BEGIN
         SELECT @n_Count = @n_Count + 1

         IF @b_debug = 1
         BEGIN
            SELECT 'Count of sizes is ' + CONVERT(char(5), @n_Count)
         END

         SELECT @c_SkuSize1 = CASE @n_Count WHEN 1 THEN @c_SkuSize
                                 ELSE @c_SkuSize1
                              END
         SELECT @c_SkuSize2 = CASE @n_Count WHEN 2 THEN @c_SkuSize
                              ELSE @c_SkuSize2
                              END
         SELECT @c_SkuSize3 = CASE @n_Count WHEN 3 THEN @c_SkuSize
                              ELSE @c_SkuSize3
                              END
         SELECT @c_SkuSize4 = CASE @n_Count WHEN 4 THEN @c_SkuSize
                              ELSE @c_SkuSize4
                              END
         SELECT @c_SkuSize5 = CASE @n_Count WHEN 5 THEN @c_SkuSize
                              ELSE @c_SkuSize5
                              END
         SELECT @c_SkuSize6 = CASE @n_Count WHEN 6 THEN @c_SkuSize
                              ELSE @c_SkuSize6
                              END
         SELECT @c_SkuSize7 = CASE @n_Count WHEN 7 THEN @c_SkuSize
                              ELSE @c_SkuSize7
                              END
         SELECT @c_SkuSize8 = CASE @n_Count WHEN 8 THEN @c_SkuSize
                              ELSE @c_SkuSize8
                              END
         SELECT @c_SkuSize9 = CASE @n_Count WHEN 9 THEN @c_SkuSize
                              ELSE @c_SkuSize9
                              END
         SELECT @c_SkuSize10 = CASE @n_Count WHEN 10 THEN @c_SkuSize
                               ELSE @c_SkuSize10
                               END
         SELECT @c_SkuSize11 = CASE @n_Count WHEN 11 THEN @c_SkuSize
                               ELSE @c_SkuSize11
                               END
         SELECT @c_SkuSize12 = CASE @n_Count WHEN 12 THEN @c_SkuSize
                               ELSE @c_SkuSize12
                               END
         SELECT @c_SkuSize13 = CASE @n_Count WHEN 13 THEN @c_SkuSize
                               ELSE @c_SkuSize13
                               END
         SELECT @c_SkuSize14 = CASE @n_Count WHEN 14 THEN @c_SkuSize
                               ELSE @c_SkuSize14
                               END
         SELECT @c_SkuSize15 = CASE @n_Count WHEN 15 THEN @c_SkuSize
                               ELSE @c_SkuSize15
                               END
         SELECT @c_SkuSize16 = CASE @n_Count WHEN 16 THEN @c_SkuSize
                               ELSE @c_SkuSize16
                               END
         SELECT @c_SkuSize17 = CASE @n_Count WHEN 17 THEN @c_SkuSize
                               ELSE @c_SkuSize17
                               END
         SELECT @c_SkuSize18 = CASE @n_Count WHEN 18 THEN @c_SkuSize
                               ELSE @c_SkuSize18
                               END
         SELECT @c_SkuSize19 = CASE @n_Count WHEN 19 THEN @c_SkuSize
                               ELSE @c_SkuSize19
                               END
         SELECT @c_SkuSize20 = CASE @n_Count WHEN 20 THEN @c_SkuSize
                               ELSE @c_SkuSize20
                               END
         SELECT @c_SkuSize21 = CASE @n_Count WHEN 21 THEN @c_SkuSize
                               ELSE @c_SkuSize21
                               END
         SELECT @c_SkuSize22 = CASE @n_Count WHEN 22 THEN @c_SkuSize
                               ELSE @c_SkuSize22
                               END
         SELECT @c_SkuSize23 = CASE @n_Count WHEN 23 THEN @c_SkuSize
                               ELSE @c_SkuSize23
                               END
         SELECT @c_SkuSize24 = CASE @n_Count WHEN 24 THEN @c_SkuSize
                               ELSE @c_SkuSize24
                               END
         SELECT @c_SkuSize25 = CASE @n_Count WHEN 25 THEN @c_SkuSize
                               ELSE @c_SkuSize25
                               END
         SELECT @c_SkuSize26 = CASE @n_Count WHEN 26 THEN @c_SkuSize
                               ELSE @c_SkuSize26
                               END
         SELECT @c_SkuSize27 = CASE @n_Count WHEN 27 THEN @c_SkuSize
                               ELSE @c_SkuSize27
                               END
         SELECT @c_SkuSize28 = CASE @n_Count WHEN 28 THEN @c_SkuSize
                               ELSE @c_SkuSize28
                               END
         SELECT @c_SkuSize29 = CASE @n_Count WHEN 29 THEN @c_SkuSize
                               ELSE @c_SkuSize29
                               END
         SELECT @c_SkuSize30 = CASE @n_Count WHEN 30 THEN @c_SkuSize
                               ELSE @c_SkuSize30
                               END
         SELECT @c_SkuSize31 = CASE @n_Count WHEN 31 THEN @c_SkuSize
                               ELSE @c_SkuSize31
                               END
         SELECT @c_SkuSize32 = CASE @n_Count WHEN 32 THEN @c_SkuSize
                               ELSE @c_SkuSize32
                               END

         IF @b_debug = 1
         BEGIN
            IF @c_TempReceiptKey = '0000907514' -- checking any OrderKey
            BEGIN
               SELECT 'SkuSize is ' + @c_SkuSize
               SELECT 'SkuSize1 to 16 is ' + @c_SkuSize1+','+ @c_SkuSize2+','+ @c_SkuSize3+','+ @c_SkuSize4+','+
                     @c_SkuSize5+','+ @c_SkuSize6+','+ @c_SkuSize7+','+ @c_SkuSize8+','+
                     @c_SkuSize9+','+ @c_SkuSize10+','+ @c_SkuSize11+','+ @c_SkuSize12+','+
                     @c_SkuSize13+','+ @c_SkuSize14+','+ @c_SkuSize15+','+ @c_SkuSize16+','+
                     @c_SkuSize17+','+ @c_SkuSize18+','+ @c_SkuSize19+','+ @c_SkuSize20+','+
                     @c_SkuSize21+','+ @c_SkuSize22+','+ @c_SkuSize23+','+ @c_SkuSize24+','+
                     @c_SkuSize25+','+ @c_SkuSize26+','+ @c_SkuSize27+','+ @c_SkuSize28+','+
                     @c_SkuSize29+','+ @c_SkuSize30+','+ @c_SkuSize31+','+ @c_SkuSize32
            END
         END

         SELECT @c_PrevStyleColor = @c_StyleColor
         SELECT @c_PrevReceiptkey = @c_Receiptkey
         SELECT @c_PrevUserDefine03 = @c_UserDefine03

         FETCH NEXT FROM pick_cur INTO @c_SkuSize, @c_Receiptkey, @c_Sort, @c_StyleColor, @c_UserDefine03                                    

         IF @b_debug = 1
         BEGIN
            SELECT 'PrevReceiptkey= ' + @c_PrevReceiptkey + ', Receiptkey = ' + @c_Receiptkey
            SELECT 'PrevStyleColor = ' + @c_PrevStyleColor + ', StyleColor= ' + @c_StyleColor
            SELECT 'PrevUserDefine03 = ' + @c_PrevUserDefine03 + ', UserDefine03= ' + @c_UserDefine03
         END

         IF (@c_PrevReceiptkey <> @c_Receiptkey) OR
            (@c_PrevReceiptkey = @c_Receiptkey AND @c_PrevStyleColor <> @c_StyleColor) OR
            (@c_PrevReceiptkey = @c_Receiptkey AND @c_PrevUserDefine03 <> @c_UserDefine03) OR
            (@@FETCH_STATUS = -1) -- last fetch
         BEGIN
            -- Insert into temp table
            INSERT INTO #TempReceipt
            SELECT RECEIPT.ReceiptKey,
                  RECEIPT.ContainerType,
                  RECEIPT.ContainerKey,
                  RECEIPT.Facility,
                  RECEIPT.ExternReceiptKey,
                  RECEIPT.ContainerQty,
                  RECEIPT.ReceiptDate,
                  ISNULL(RTRIM(SKU.Style),'') + ISNULL(RTRIM(SKU.Color),'') StyleColor,
                  RECEIPTDETAIL.UserDefine03,
                  CASE WHEN ISNUMERIC(CL.Short) = 1 AND ISNULL(CL.Short,0) > 0 THEN CL.Short ELSE 0 END AS Casecnt,
                  SKU.Descr,
                  --CASE WHEN RECEIPT.[RECType] = 'MIXPACK' THEN SUM(tmp.UserDefine02) ELSE SUM(RECEIPTDETAIL.QTYEXPECTED) END,
                  SUM(RECEIPTDETAIL.QTYEXPECTED),
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
                  -- SOS29528
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
                  --(Wan03) - START
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize1 --AND ISNULL(SKU.Size,'') <> ''
                                 /*THEN CASE WHEN ORDERS.[Type] = 'X' 
                                           THEN (SELECT COUNT(DISTINCT ORDERDETAIL.Userdefine02) FROM ORDERDETAIL (NOLOCK) 
                                                 WHERE ORDERDETAIL.Orderkey = ORDERS.Orderkey
                                                 AND ORDERDETAIL.SKU = SKU.SKU AND ORDERDETAIL.Userdefine03 = OD.Userdefine03)
                                           ELSE SUM(PICKDETAIL.Qty) END*/
                                 THEN CASE WHEN RECEIPT.[RECType] = 'MIXPACK' THEN SUM(tmp.UserDefine02) ELSE SUM(RECEIPTDETAIL.QTYEXPECTED) END
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize2 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN CASE WHEN RECEIPT.[RECType] = 'MIXPACK' THEN SUM(tmp.UserDefine02) ELSE SUM(RECEIPTDETAIL.QTYEXPECTED) END
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize3 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN CASE WHEN RECEIPT.[RECType] = 'MIXPACK' THEN SUM(tmp.UserDefine02) ELSE SUM(RECEIPTDETAIL.QTYEXPECTED) END
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize4 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN CASE WHEN RECEIPT.[RECType] = 'MIXPACK' THEN SUM(tmp.UserDefine02) ELSE SUM(RECEIPTDETAIL.QTYEXPECTED) END
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize5 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN CASE WHEN RECEIPT.[RECType] = 'MIXPACK' THEN SUM(tmp.UserDefine02) ELSE SUM(RECEIPTDETAIL.QTYEXPECTED) END
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize6 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN CASE WHEN RECEIPT.[RECType] = 'MIXPACK' THEN SUM(tmp.UserDefine02) ELSE SUM(RECEIPTDETAIL.QTYEXPECTED) END
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize7 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN CASE WHEN RECEIPT.[RECType] = 'MIXPACK' THEN SUM(tmp.UserDefine02) ELSE SUM(RECEIPTDETAIL.QTYEXPECTED) END
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize8 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN CASE WHEN RECEIPT.[RECType] = 'MIXPACK' THEN SUM(tmp.UserDefine02) ELSE SUM(RECEIPTDETAIL.QTYEXPECTED) END
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize9 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN CASE WHEN RECEIPT.[RECType] = 'MIXPACK' THEN SUM(tmp.UserDefine02) ELSE SUM(RECEIPTDETAIL.QTYEXPECTED) END
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize10 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN CASE WHEN RECEIPT.[RECType] = 'MIXPACK' THEN SUM(tmp.UserDefine02) ELSE SUM(RECEIPTDETAIL.QTYEXPECTED) END
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize11 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN CASE WHEN RECEIPT.[RECType] = 'MIXPACK' THEN SUM(tmp.UserDefine02) ELSE SUM(RECEIPTDETAIL.QTYEXPECTED) END
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize12 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN CASE WHEN RECEIPT.[RECType] = 'MIXPACK' THEN SUM(tmp.UserDefine02) ELSE SUM(RECEIPTDETAIL.QTYEXPECTED) END
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize13 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN CASE WHEN RECEIPT.[RECType] = 'MIXPACK' THEN SUM(tmp.UserDefine02) ELSE SUM(RECEIPTDETAIL.QTYEXPECTED) END
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize14 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN CASE WHEN RECEIPT.[RECType] = 'MIXPACK' THEN SUM(tmp.UserDefine02) ELSE SUM(RECEIPTDETAIL.QTYEXPECTED) END
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize15 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN CASE WHEN RECEIPT.[RECType] = 'MIXPACK' THEN SUM(tmp.UserDefine02) ELSE SUM(RECEIPTDETAIL.QTYEXPECTED) END
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize16 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN CASE WHEN RECEIPT.[RECType] = 'MIXPACK' THEN SUM(tmp.UserDefine02) ELSE SUM(RECEIPTDETAIL.QTYEXPECTED) END
                                 ELSE 0
                                 END,
                  -- SOS29528   
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize17 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN CASE WHEN RECEIPT.[RECType] = 'MIXPACK' THEN SUM(tmp.UserDefine02) ELSE SUM(RECEIPTDETAIL.QTYEXPECTED) END
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize18 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN CASE WHEN RECEIPT.[RECType] = 'MIXPACK' THEN SUM(tmp.UserDefine02) ELSE SUM(RECEIPTDETAIL.QTYEXPECTED) END
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize19 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN CASE WHEN RECEIPT.[RECType] = 'MIXPACK' THEN SUM(tmp.UserDefine02) ELSE SUM(RECEIPTDETAIL.QTYEXPECTED) END
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize20 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN CASE WHEN RECEIPT.[RECType] = 'MIXPACK' THEN SUM(tmp.UserDefine02) ELSE SUM(RECEIPTDETAIL.QTYEXPECTED) END
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize21 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN CASE WHEN RECEIPT.[RECType] = 'MIXPACK' THEN SUM(tmp.UserDefine02) ELSE SUM(RECEIPTDETAIL.QTYEXPECTED) END
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize22 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN CASE WHEN RECEIPT.[RECType] = 'MIXPACK' THEN SUM(tmp.UserDefine02) ELSE SUM(RECEIPTDETAIL.QTYEXPECTED) END
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize23 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN CASE WHEN RECEIPT.[RECType] = 'MIXPACK' THEN SUM(tmp.UserDefine02) ELSE SUM(RECEIPTDETAIL.QTYEXPECTED) END
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize24 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN CASE WHEN RECEIPT.[RECType] = 'MIXPACK' THEN SUM(tmp.UserDefine02) ELSE SUM(RECEIPTDETAIL.QTYEXPECTED) END
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize25 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN CASE WHEN RECEIPT.[RECType] = 'MIXPACK' THEN SUM(tmp.UserDefine02) ELSE SUM(RECEIPTDETAIL.QTYEXPECTED) END
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize26 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN CASE WHEN RECEIPT.[RECType] = 'MIXPACK' THEN SUM(tmp.UserDefine02) ELSE SUM(RECEIPTDETAIL.QTYEXPECTED) END
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize27 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN CASE WHEN RECEIPT.[RECType] = 'MIXPACK' THEN SUM(tmp.UserDefine02) ELSE SUM(RECEIPTDETAIL.QTYEXPECTED) END
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize28 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN CASE WHEN RECEIPT.[RECType] = 'MIXPACK' THEN SUM(tmp.UserDefine02) ELSE SUM(RECEIPTDETAIL.QTYEXPECTED) END
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize29 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN CASE WHEN RECEIPT.[RECType] = 'MIXPACK' THEN SUM(tmp.UserDefine02) ELSE SUM(RECEIPTDETAIL.QTYEXPECTED) END
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize30 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN CASE WHEN RECEIPT.[RECType] = 'MIXPACK' THEN SUM(tmp.UserDefine02) ELSE SUM(RECEIPTDETAIL.QTYEXPECTED) END
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize31 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN CASE WHEN RECEIPT.[RECType] = 'MIXPACK' THEN SUM(tmp.UserDefine02) ELSE SUM(RECEIPTDETAIL.QTYEXPECTED) END
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize32 AND ISNULL(SKUSZ.Size,'') <> ''
                                     THEN CASE WHEN RECEIPT.[RECType] = 'MIXPACK' THEN SUM(tmp.UserDefine02) ELSE SUM(RECEIPTDETAIL.QTYEXPECTED) END
                                     ELSE 0
                                     END,
                  CASE WHEN ISNULL(CL1.Code,'') = RECEIPT.[RECType] THEN ISNULL(CL1.Long,'') ELSE ISNULL(CL1.Notes,'') END AS Logo,
                  RECEIPT.[RECType]
            FROM RECEIPT WITH (NOLOCK)
            JOIN RECEIPTDETAIL WITH (NOLOCK) ON RECEIPTDETAIL.Receiptkey = RECEIPT.Receiptkey
            JOIN SKU WITH (NOLOCK) ON (SKU.SKU = RECEIPTDETAIL.SKU AND SKU.Storerkey = RECEIPT.Storerkey)
            JOIN #SKUSZ  SKUSZ WITH (NOLOCK) ON (RECEIPT.Receiptkey = SKUSZ.Receiptkey)                          
                                             AND(SKU.Storerkey = SKUSZ.Storerkey AND SKU.SKU = SKUSZ.SKU)   
            CROSS APPLY (SELECT SUM(UserDefine02) AS UserDefine02 FROM #TEMPUSERDEFINE02 WHERE RECEIPT.Receiptkey = Receiptkey                          
                                             AND SKU.Storerkey = Storerkey AND SKU.SKU = SKU AND UserDefine03 = @c_PrevUserdefine03 ) AS tmp 
            LEFT JOIN CODELKUP CL WITH (NOLOCK) ON CL.Listname = 'SKXMIXPACK' AND CL.Code = RECEIPTDETAIL.Userdefine03
                                               AND CL.Storerkey = RECEIPT.Storerkey
            LEFT JOIN CODELKUP CL1 WITH (NOLOCK) ON CL1.Listname = 'RPTLOGO' AND CL1.Code = 'MIXPACK'
                                               AND CL1.Storerkey = RECEIPT.Storerkey
            WHERE RECEIPT.ReceiptKey = @c_PrevReceiptkey
              AND ISNULL(RTRIM(SKU.Style),'') + ISNULL(RTRIM(SKU.Color),'') = @c_PrevStyleColor
              AND RECEIPTDETAIL.UserDefine03 = @c_PrevUserdefine03
            AND 1=CASE SKUSZ.SIZE WHEN @c_SkuSize1 THEN 1                                                   --(Wan03)
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
                                  -- SOS29528
                                  WHEN @c_SkuSize17 THEN 1
                                  WHEN @c_SkuSize18 THEN 1
                                  WHEN @c_SkuSize19 THEN 1
                                  WHEN @c_SkuSize20 THEN 1
                                  WHEN @c_SkuSize21 THEN 1
                                  WHEN @c_SkuSize22 THEN 1
                                  WHEN @c_SkuSize23 THEN 1
                                  WHEN @c_SkuSize24 THEN 1
                                  WHEN @c_SkuSize25 THEN 1
                                  WHEN @c_SkuSize26 THEN 1
                                  WHEN @c_SkuSize27 THEN 1
                                  WHEN @c_SkuSize28 THEN 1
                                  WHEN @c_SkuSize29 THEN 1
                                  WHEN @c_SkuSize30 THEN 1
                                  WHEN @c_SkuSize31 THEN 1
                                  WHEN @c_SkuSize32 THEN 1
                    ELSE 0
                    END
            GROUP BY RECEIPT.ReceiptKey,
                     RECEIPT.ContainerType,
                     RECEIPT.ContainerKey,
                     RECEIPT.Facility,
                     RECEIPT.ExternReceiptKey,
                     RECEIPT.ContainerQty,
                     RECEIPT.ReceiptDate,
                     ISNULL(RTRIM(SKU.Style),'') + ISNULL(RTRIM(SKU.Color),''),
                     RECEIPTDETAIL.UserDefine03,
                     CASE WHEN ISNUMERIC(CL.Short) = 1 AND ISNULL(CL.Short,0) > 0 THEN CL.Short ELSE 0 END,
                     SKU.Descr,
                     CASE WHEN ISNULL(CL1.Code,'') = RECEIPT.[RECType] THEN ISNULL(CL1.Long,'') ELSE ISNULL(CL1.Notes,'') END,
                     SKUSZ.SIZE, RECEIPT.[RECType]
            --ORDER BY LOADPLANDETAIL.Loadkey,
            --         ORDERS.DeliveryDate,
            --         ORDERS.Orderkey,
            --         LOC.LogicalLocation,
            --         ISNULL(RTRIM(PICKDETAIL.Loc),''),
            --         ISNULL(RTRIM(SKU.Style),'') + ISNULL(RTRIM(SKU.Color),''),
            --         SizeSort

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
         END
      END -- WHILE (@@FETCH_STATUS <> -1)
      CLOSE pick_cur
      DEALLOCATE pick_cur
   END -- WHILE (1 = 1)
   --select * from #TempReceipt
   SELECT Receiptkey, ContainerType, Containerkey, Facility, ExternReceiptkey,
         ContainerQty, ReceiptDate, StyleColor, UserDefine03,Casecnt, SKUDescr, SUM(QtyExpected) QtyExpected,
         SkuSize1, SkuSize2, SkuSize3, SkuSize4, SkuSize5, SkuSize6, SkuSize7, SkuSize8,
         SkuSize9, SkuSize10, SkuSize11, SkuSize12, SkuSize13, SkuSize14, SkuSize15, SkuSize16,
         -- SOS29528
         SkuSize17, SkuSize18, SkuSize19, SkuSize20, SkuSize21, SkuSize22, SkuSize23, SkuSize24,
         SkuSize25, SkuSize26, SkuSize27, SkuSize28, SkuSize29, SkuSize30, SkuSize31, SkuSize32,
         SUM(Qty1) Qty1, SUM(Qty2) Qty2, SUM(Qty3) Qty3, SUM(Qty4) Qty4, SUM(Qty5) Qty5, SUM(Qty6) Qty6,
         SUM(Qty7) Qty7, SUM(Qty8) Qty8, SUM(Qty9) Qty9, SUM(Qty10) Qty10, SUM(Qty11) Qty11, SUM(Qty12) Qty12,
         SUM(Qty13) Qty13, SUM(Qty14) Qty14, SUM(Qty15) Qty15, SUM(Qty16) Qty16,
         -- SOS29528
         SUM(Qty17) Qty17, SUM(Qty18) Qty18, SUM(Qty19) Qty19, SUM(Qty20) Qty20, SUM(Qty21) Qty21, SUM(Qty22) Qty22,
         SUM(Qty23) Qty23, SUM(Qty24) Qty24, SUM(Qty25) Qty25, SUM(Qty26) Qty26, SUM(Qty27) Qty27, SUM(Qty28) Qty28,
         SUM(Qty29) Qty29, SUM(Qty30) Qty30, SUM(Qty31) Qty31, SUM(Qty32) Qty32
         , Logo
         , (Row_Number() OVER (PARTITION BY Receiptkey Order By Receiptkey, StyleColor, CASE WHEN RECType = 'MIXPACK' THEN Casecnt END Asc) - 1 ) / @n_MaxLine + 1 AS Pagegroup
   FROM #TempReceipt WITH (NOLOCK)
   GROUP BY Receiptkey, ContainerType, Containerkey, Facility, ExternReceiptkey,
            ContainerQty, ReceiptDate, StyleColor, UserDefine03,Casecnt, SKUDescr,
            SkuSize1, SkuSize2, SkuSize3, SkuSize4, SkuSize5, SkuSize6, SkuSize7, SkuSize8,
            SkuSize9, SkuSize10, SkuSize11, SkuSize12, SkuSize13, SkuSize14, SkuSize15, SkuSize16,
            -- SOS29528
            SkuSize17, SkuSize18, SkuSize19, SkuSize20, SkuSize21, SkuSize22, SkuSize23, SkuSize24,
            SkuSize25, SkuSize26, SkuSize27, SkuSize28, SkuSize29, SkuSize30, SkuSize31, SkuSize32,
            Logo, RECType
   ORDER BY Receiptkey, StyleColor, CASE WHEN RECType = 'MIXPACK' THEN Casecnt END

   DROP TABLE #TempReceipt
   DROP TABLE #TempReceiptKey
END

GO