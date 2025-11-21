SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  ispGetStockTakeSheet                               */
/* Creation Date: 12-NOV-2002                                           */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Generate Count Sheet                                        */
/*                                                                      */
/*                                                                      */
/* Called By: r_dw_stocktake_my                                         */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date          Author        Purposes                                 */
/* 17-Mar-2004   MaryVong      Add Drop Object                          */
/* 01-Oct-2004   wmacaraig     Cater for no SKUGROUP Setup              */
/* 22-Sep-2005   ONG           SOS40884 Add CCDetail.SystemQty          */
/* 07-Dec-2006   MaryVong      SOS63326 Display CCKey                   */
/* 08-Feb-2010   Leong         SOS# 161802 - Join with StorerKey        */
/* 06-Dec-2012   Audrey        SOS#263856 - Default Logo by cckey(ang01)*/
/* 14-May-2013   NJOW01        278295-Use storerconfig CCSHEETBYPASSPA  */
/*                             to bypass zone                           */
/* 30-May-2013   NJOW02        Fix empty loc not show issue             */
/* 24-JAN-2014   YTWan         SOS#300785 - [GIGA] Change request on    */
/*                             RCM Report - Count Sheet (Wan01)         */
/* 22-MAY-2014   CSCHONG       Added Lottables 06-15 (CS01)             */
/* 12-MAY-2021   Mingle        Added showlot08 and showlot12(ML01)      */
/* 26-Nov-2021   CHONGCS       Devops Scripts Combine                   */
/* 26-Nov-2021   CHONGCS       WMS-18381 loc barcode with config(CS02)  */
/************************************************************************/

CREATE PROC [dbo].[ispGetStockTakeSheet] (
@c_CCKey_Start       NVARCHAR(10),
@c_CCKey_End         NVARCHAR(10),
@c_Sku_Start         NVARCHAR(20),
@c_Sku_End           NVARCHAR(20),
@c_SKUClass_Start    NVARCHAR(10),
@c_SKUClass_End      NVARCHAR(10),
@c_StorerKey_Start   NVARCHAR(15),
@c_StorerKey_End     NVARCHAR(15),
@c_Loc_Start         NVARCHAR(10),
@c_Loc_End           NVARCHAR(10),
@c_zone_start       NVARCHAR(10),
@c_zone_end          NVARCHAR(10),
@c_ccsheetno_start NVARCHAR(10),
@c_ccsheetno_end  NVARCHAR(10),
@c_withqty NVARCHAR(1),
@c_CountNo  NVARCHAR(1)
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

Declare @C_STORERKEY varchar (15)

   --(Wan01) - START
   DECLARE  @n_UDF01IsCol     INT
         ,  @n_UDF02IsCol     INT
         ,  @n_UDF03IsCol     INT

         ,  @n_CombineSku     INT
         ,  @c_UDF01          NVARCHAR(30)
         ,  @c_UDF02          NVARCHAR(30) 
         ,  @c_UDF03          NVARCHAR(30) 
         ,  @c_TableName      NVARCHAR(30)
         ,  @c_SQL            NVARCHAR(MAX)
   --(Wan01) - END
         , @c_getstorerkey    NVARCHAR(20)= ''  --CS02



     --CS02 START
     IF ISNULL(@c_StorerKey_Start,'') <> '' AND EXISTS (SELECT 1 FROM Storer (NOLOCK) WHERE storerkey = @c_StorerKey_Start)
     BEGIN
        SET @c_getstorerkey = @c_StorerKey_Start  
     END 
     ELSE IF ISNULL(@c_StorerKey_end,'') <> '' AND @c_StorerKey_End NOT LIKE 'ZZZ%' AND EXISTS (SELECT 1 FROM Storer (NOLOCK) WHERE storerkey = @c_StorerKey_end)
     BEGIN
        SET @c_getstorerkey = @c_StorerKey_end 
     END 
     ELSE
     BEGIN
       SELECT TOP 1 @c_getstorerkey = StorerKey
       FROM dbo.StockTakeSheetParameters WITH (NOLOCK)
       WHERE StockTakeKey = @c_CCKey_Start OR StockTakeKey = @c_CCKey_End
     END

     --CS02 END

create table #RESULT 
(
cckey NVARCHAR(10) null
, ccsheetno NVARCHAR(10) null
, lot NVARCHAR(10) null
, loc NVARCHAR(10) null
, id NVARCHAR(18) null
, storerkey NVARCHAR(15) null
, sku NVARCHAR(20) null
, descr NVARCHAR(60) null
, Lottable01 NVARCHAR(18) null
, Lottable02 NVARCHAR(18) null
, Lottable03 NVARCHAR(18) null
, Lottable04 datetime null
, Lottable05 datetime null
, Qty Int null
, packuom3 NVARCHAR(10) null
, putawayzone NVARCHAR(10) null
, loclevel int null
, locaisle NVARCHAR(10) null
, facility NVARCHAR(5) null
, CaseCnt float null
, SKUGroupDesc NVARCHAR(60) null
, SKUGroup NVARCHAR(10) null
, PalletCnt float null
, CCDetailKey NVARCHAR(10) null
, SystemQty int null
, Lottable06 NVARCHAR(30) null      --(CS01)
, Lottable07 NVARCHAR(30) null      --(CS01)
, Lottable08 NVARCHAR(30) null      --(CS01)
, Lottable09 NVARCHAR(30) null      --(CS01)
, Lottable10 NVARCHAR(30) null      --(CS01)
, Lottable11 NVARCHAR(30) null      --(CS01)
, Lottable12 NVARCHAR(30) null      --(CS01)
, Lottable13 datetime null          --(CS01)
, Lottable14 datetime null          --(CS01)
, Lottable15 datetime null          --(CS01)
, showlot08 NVARCHAR(30) NULL       --(ML01)
, showlot12 NVARCHAR(30) NULL       --(ML01)
, showlocbarcode NVARCHAR(5) NULL   --(CS02)
)

 -- prepare result table
INSERT INTO #RESULT
(  cckey
, ccsheetno
, lot
, loc
, id
, storerkey
, sku
, descr
, Lottable01
, Lottable02
, Lottable03
, Lottable04
, Lottable05
, Qty
, packuom3
, putawayzone
, loclevel
, locaisle
, facility
, CaseCnt
, SKUGroupDesc
, SKUGroup
, PalletCnt
, CCDetailKey
, SystemQty
, Lottable06      --(CS01)
, Lottable07      --(CS01) 
, Lottable08      --(CS01)
, Lottable09      --(CS01)
, Lottable10      --(CS01)
, Lottable11      --(CS01)
, Lottable12      --(CS01)
, Lottable13      --(CS01)
, Lottable14      --(CS01)
, Lottable15      --(CS01)
, showlot08       --(ML01)
, showlot12       --(ML01)
,showlocbarcode    --(CS02)
)
 SELECT CCDETAIL.CCKey,  -- SOS63326
  CCDETAIL.ccsheetno,
  CCDETAIL.lot,
  CCDETAIL.loc,
  CCDETAIL.id,
  CCDETAIL.storerkey,
  CCDETAIL.sku,
  descr = space(60),
      CASE @c_CountNo
           WHEN '1' THEN CCDETAIL.lottable01
           WHEN '2' THEN CCDETAIL.lottable01_Cnt2
           WHEN '3' THEN CCDETAIL.lottable01_Cnt3
      END as Lottable01,
      CASE @c_CountNo
           WHEN '1' THEN CCDETAIL.lottable02
           WHEN '2' THEN CCDETAIL.lottable02_Cnt2
           WHEN '3' THEN CCDETAIL.lottable02_Cnt3
      END as Lottable02,
      CASE @c_CountNo
           WHEN '1' THEN CCDETAIL.lottable03
           WHEN '2' THEN CCDETAIL.lottable03_Cnt2
           WHEN '3' THEN CCDETAIL.lottable03_Cnt3
      END as Lottable03,
      CASE @c_CountNo
           WHEN '1' THEN CCDETAIL.lottable04
           WHEN '2' THEN CCDETAIL.lottable04_Cnt2
           WHEN '3' THEN CCDETAIL.lottable04_Cnt3
      END as Lottable04,
      CASE @c_CountNo
           WHEN '1' THEN CCDETAIL.lottable05
           WHEN '2' THEN CCDETAIL.lottable05_Cnt2
           WHEN '3' THEN CCDETAIL.lottable05_Cnt3
      END as Lottable05,
      CASE @c_CountNo
           WHEN '1' THEN CCDETAIL.qty
           WHEN '2' THEN CCDETAIL.Qty_Cnt2
           WHEN '3' THEN CCDETAIL.Qty_Cnt3
      END AS Qty,
  packuom3 = space(10),
  CASE WHEN ISNULL(SC.Svalue,'0')='1' THEN '' ELSE LOC.putawayzone END AS Putawayzone,  --NJOW01
  LOC.loclevel,
  LOC.locaisle,
  LOC.facility,
  CaseCnt = 0,
  SKUGroupDesc = SPACE(60),
  SKUGroup=SPACE(10),
  PalletCnt = 0,
  CCDetailKey,
  CCDETAIL.SystemQty,    -- 22Sep2005 by ONG SOS40884, It will be set to '0' IF @c_withqty <> 'Y'
  /*CS01 Start*/
  CASE @c_CountNo
           WHEN '1' THEN CCDETAIL.lottable06
           WHEN '2' THEN CCDETAIL.lottable06_Cnt2
           WHEN '3' THEN CCDETAIL.lottable06_Cnt3
      END as Lottable06,
      CASE @c_CountNo
           WHEN '1' THEN CCDETAIL.lottable07
           WHEN '2' THEN CCDETAIL.lottable07_Cnt2
           WHEN '3' THEN CCDETAIL.lottable07_Cnt3
      END as Lottable07,
      CASE @c_CountNo
           WHEN '1' THEN CCDETAIL.lottable08
           WHEN '2' THEN CCDETAIL.lottable08_Cnt2
           WHEN '3' THEN CCDETAIL.lottable08_Cnt3
      END as Lottable08,
      CASE @c_CountNo
           WHEN '1' THEN CCDETAIL.lottable09
           WHEN '2' THEN CCDETAIL.lottable09_Cnt2
           WHEN '3' THEN CCDETAIL.lottable09_Cnt3
      END as Lottable09,
      CASE @c_CountNo
           WHEN '1' THEN CCDETAIL.lottable10
           WHEN '2' THEN CCDETAIL.lottable10_Cnt2
           WHEN '3' THEN CCDETAIL.lottable10_Cnt3
      END as Lottable10,
      CASE @c_CountNo
           WHEN '1' THEN CCDETAIL.lottable11
           WHEN '2' THEN CCDETAIL.lottable11_Cnt2
           WHEN '3' THEN CCDETAIL.lottable11_Cnt3
      END as Lottable011,
      CASE @c_CountNo
           WHEN '1' THEN CCDETAIL.lottable12
           WHEN '2' THEN CCDETAIL.lottable12_Cnt2
           WHEN '3' THEN CCDETAIL.lottable12_Cnt3
      END as Lottable12,
      CASE @c_CountNo
           WHEN '1' THEN CCDETAIL.lottable13
           WHEN '2' THEN CCDETAIL.lottable13_Cnt2
           WHEN '3' THEN CCDETAIL.lottable13_Cnt3
      END as Lottable13,
      CASE @c_CountNo
           WHEN '1' THEN CCDETAIL.lottable14
           WHEN '2' THEN CCDETAIL.lottable14_Cnt2
           WHEN '3' THEN CCDETAIL.lottable14_Cnt3
      END as Lottable14,
      CASE @c_CountNo
           WHEN '1' THEN CCDETAIL.lottable15
           WHEN '2' THEN CCDETAIL.lottable15_Cnt2
           WHEN '3' THEN CCDETAIL.lottable15_Cnt3
      END as Lottable15,
      /*CS01 END*/
      showlot08 = CASE WHEN CCDETAIL.StorerKey = 'IDSMED' THEN Lottable08 ELSE Lottable02 END,     --(ML01)
      showlot12 = CASE WHEN CCDETAIL.StorerKey = 'IDSMED' THEN Lottable12 ELSE SKU.SkuGroup END,      --(ML01)
      showlocbarcode = CASE WHEN ISNULL(CL.Code,'') <> '' THEN 'Y' ELSE 'N' END                  --(CS02) 
 FROM CCDETAIL (NOLOCK)
 LEFT OUTER JOIN  LOC (NOLOCK) ON (LOC.loc = CCDETAIL.loc)
 LEFT OUTER JOIN  SKU (NOLOCK) ON (CCDETAIL.StorerKey = SKU.StorerKey AND CCDETAIL.SKU = SKU.SKU)
 LEFT OUTER JOIN  dbo.V_STORERCONFIG2 SC (NOLOCK) ON (CCDETAIL.StorerKey = SC.Storerkey AND SC.Configkey = 'CCSHEETBYPASSPA') --NJOW01
 LEFT JOIN dbo.CODELKUP CL WITH (NOLOCK) ON CL.LISTNAME='REPORTCFG' AND CL.code = 'SHOWLOCBARCODE' AND CL.long='r_dw_stocktake_my' --(CS02)
                                        AND CL.Storerkey= @c_getstorerkey AND ISNULL(CL.Short,'') <> 'N'                                                    --(CS02)
 WHERE CCDETAIL.CCKey BETWEEN @c_CCKey_Start AND @c_CCKey_End
   AND   CCDETAIL.ccsheetno BETWEEN @c_ccsheetno_start AND @c_ccsheetno_end
   AND   LOC.PutawayZone BETWEEN @c_zone_start AND @c_zone_end
   AND   LOC.LOC BETWEEN @c_Loc_start AND @c_Loc_end

--SELECT * from #RESULT

 IF @c_withqty = 'Y'
  UPDATE #RESULT
                  SET #RESULT.packuom3 = PACK.packuom3,
                      #RESULT.descr = SKU.descr,
                      #RESULT.CaseCnt = PACK.CaseCnt,
                      #RESULT.PalletCnt = PACK.Pallet,
                      #RESULT.SKUGroupDesc = CODELKUP.Description,
                      #RESULT.SKUGroup = SKU.SKUGroup
  FROM SKU (NOLOCK) INNER JOIN #RESULT
  ON SKU.sku = #RESULT.sku
  AND SKU.StorerKey = #RESULT.StorerKey -- SOS# 161802
  INNER JOIN PACK
  ON SKU.packkey = PACK.packkey
                LEFT OUTER JOIN CodeLkUp
                ON SKU.SKUGroup = CodeLkUp.Code
                AND CodeLkUp.ListName = 'SKUGROUP'
 ELSE
  UPDATE #RESULT
                     SET #RESULT.packuom3 = PACK.packuom3,
                      #RESULT.descr = SKU.descr,
                      #RESULT.Qty = 0,
                      #RESULT.CaseCnt = PACK.CaseCnt,
                      #RESULT.PalletCnt = PACK.Pallet,
                      #RESULT.SKUGroupDesc = CODELKUP.Description,
                      #RESULT.SKUGroup = SKU.SKUGroup,
                      #RESULT.SystemQty = 0
  FROM SKU (NOLOCK) 
  INNER JOIN #RESULT  ON SKU.sku = #RESULT.sku  AND SKU.StorerKey = #RESULT.StorerKey -- SOS# 161802
  INNER JOIN PACK  ON SKU.packkey = PACK.packkey
   LEFT OUTER JOIN CodeLkUp ON SKU.SKUGroup = CodeLkUp.Code
                            AND CodeLkUp.ListName = 'SKUGROUP'

--ang01 Start
 SELECT #RESULT.CCKEY  AS 'CCKEY1',
        MAX(STORERKEY) AS 'STORERFORLOGO'
INTO #RESULT1
FROM #RESULT
GROUP BY CCKEY


--(Wan01) - START
   DECLARE CUR_STR CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT Storerkey                                
   FROM #RESULT  
   WHERE Storerkey <> '' AND Sku <> ''

   OPEN CUR_STR
   
   FETCH NEXT FROM CUR_STR INTO  @c_Storerkey                                        
                             
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @c_UDF01 = ''
      SET @c_UDF02 = ''
      SET @c_UDF03 = ''
      SET @n_CombineSku = 0
     
      SELECT @c_UDF01 = ISNULL(UDF01,'')
            ,@c_UDF02 = ISNULL(UDF02,'')
            ,@c_UDF03 = ISNULL(UDF03,'')
            ,@n_CombineSku = 1
      FROM CODELKUP WITH (NOLOCK)
      WHERE Listname = 'COMBINESKU'
      AND Code = 'CONCATENATESKU'
      AND Storerkey = @c_Storerkey   
      
      IF @n_CombineSku = 1
      BEGIN
         SET @c_TableName = ''
         SET @c_TableName = CASE WHEN CHARINDEX('.', @c_UDF01) > 0 
                                 THEN SUBSTRING(@c_UDF01, 1, CHARINDEX('.', @c_UDF01)-1)
                                 WHEN CHARINDEX('.', @c_UDF02) > 0 
                                 THEN SUBSTRING(@c_UDF02, 1, CHARINDEX('.', @c_UDF02)-1)
                                 WHEN CHARINDEX('.', @c_UDF03) > 0 
                                 THEN SUBSTRING(@c_UDF03, 1, CHARINDEX('.', @c_UDF03)-1)
                                 ELSE 'SKU'
                                 END

         SET @c_UDF01 = CASE WHEN CHARINDEX('.', @c_UDF01) > 0 
                             THEN SUBSTRING(@c_UDF01, CHARINDEX('.', @c_UDF01)+1, LEN(@c_UDF01) - CHARINDEX('.', @c_UDF01))
                             ELSE @c_UDF01
                             END

         SET @c_UDF02 = CASE WHEN CHARINDEX('.', @c_UDF02) > 0 
                             THEN SUBSTRING(@c_UDF02, CHARINDEX('.', @c_UDF02)+1, LEN(@c_UDF02) - CHARINDEX('.', @c_UDF02))
                             ELSE @c_UDF02
                             END

         SET @c_UDF03 = CASE WHEN CHARINDEX('.', @c_UDF03) > 0 
                             THEN SUBSTRING(@c_UDF03, CHARINDEX('.', @c_UDF03)+1, LEN(@c_UDF03) - CHARINDEX('.', @c_UDF03))
                             ELSE @c_UDF03
                             END

         SET @n_UDF01IsCol = 0
         SET @n_UDF02IsCol = 0
         SET @n_UDF03IsCol = 0

         SELECT @n_UDF01IsCol =  MAX(CASE WHEN COLUMN_NAME = @c_UDF01 THEN 1 ELSE 0 END)
               ,@n_UDF02IsCol =  MAX(CASE WHEN COLUMN_NAME = @c_UDF02 THEN 1 ELSE 0 END)
               ,@n_UDF03IsCol =  MAX(CASE WHEN COLUMN_NAME = @c_UDF03 THEN 1 ELSE 0 END)
         FROM   INFORMATION_SCHEMA.COLUMNS 
         WHERE  TABLE_NAME = @c_TableName


         SET @c_UDF01 = CASE WHEN @n_UDF01IsCol = 1 
                             THEN 'RTRIM(' + @c_TableName + '.' + @c_UDF01 + ')'
                             ELSE '''' + @c_UDF01 + ''''
                             END

         SET @c_UDF02 = CASE WHEN @n_UDF02IsCol = 1 
                             THEN 'RTRIM(' + @c_TableName + '.' + @c_UDF02 + ')'
                             ELSE '''' + @c_UDF02 + ''''
                             END

         SET @c_UDF03 = CASE WHEN @n_UDF03IsCol = 1 
                             THEN 'RTRIM(' + @c_TableName + '.' + @c_UDF03 + ')'
                             ELSE '''' + @c_UDF03 + ''''
                             END

         SET @c_SQL = ''
         SET @c_SQL = N' UPDATE #RESULT'
                    +  ' SET SKU = ' + @c_UDF01 + ' + ' + @c_UDF02 + ' + ' + @c_UDF03
                    +  ' FROM  #RESULT TMP '
                    +  ' JOIN ' + @c_TableName + ' WITH (NOLOCK) ON  TMP.Storerkey = SKU.Storerkey'
                    +                                          ' AND TMP.Sku = SKU.Sku' 
                    +  ' WHERE TMP.Storerkey = ''' + @c_storerkey + ''''
      
         EXEC ( @c_SQL )
      END
      FETCH NEXT FROM CUR_STR INTO  @c_Storerkey 
   END
   CLOSE CUR_STR
   DEALLOCATE CUR_STR
--(Wan01) - END

SELECT 
#RESULT.cckey,
#RESULT.ccsheetno,
#RESULT.lot,
#RESULT.loc,
#RESULT.id,
#RESULT.storerkey,
#RESULT.sku,
#RESULT.descr,
#RESULT.Lottable01,
#RESULT.Lottable02,
#RESULT.Lottable03,
#RESULT.Lottable04,
#RESULT.Lottable05,
#RESULT.Qty,
#RESULT.packuom3,
#RESULT.putawayzone,
#RESULT.loclevel,
#RESULT.locaisle,
#RESULT.facility,
#RESULT.CaseCnt,
#RESULT.SKUGroupDesc,
#RESULT.SKUGroup,
#RESULT.PalletCnt,
#RESULT.CCDetailKey,
#RESULT.SystemQty,
#RESULT1.STORERFORLOGO,
#RESULT.Lottable06,     --(CS01)
#RESULT.Lottable07,     --(CS01)
#RESULT.Lottable08,     --(CS01)
#RESULT.Lottable09,     --(CS01)
#RESULT.Lottable10,     --(CS01)
#RESULT.Lottable11,     --(CS01)
#RESULT.Lottable12,     --(CS01)
#RESULT.Lottable13,     --(CS01)
#RESULT.Lottable14,     --(CS01)
#RESULT.Lottable15,     --(CS01)
#RESULT.showlot08,      --(ML01)
#RESULT.showlot12,      --(ML01)
#RESULT.showlocbarcode  --(CS02)
FROM #RESULT
JOIN  #RESULT1 ON (#RESULT.cckey = #RESULT1.CCKEy1) --ang01 End
   WHERE (StorerKey BETWEEN @c_StorerKey_Start AND @c_StorerKey_End OR ISNULL(Storerkey,'')='') --NJOW02
   AND   (SKU BETWEEN @c_SKU_Start AND @c_SKU_End OR ISNULL(SKU,'')='') --NJOW02
   -- AND   itemclass Between @c_SKUClass_Start AND @c_SKUClass_End

 DROP TABLE #RESULT
 DROP TABLE #RESULT1 --ang01
END


GO