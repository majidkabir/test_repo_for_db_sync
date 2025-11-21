SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: isp_CC_Sheet_Summary                                */
/* Creation Date: 2015-10-30                                             */
/* Copyright: IDS                                                        */
/* Written by:                                                           */
/*                                                                       */
/* Purpose: SOS#354882 - JP_H&M_DN Report                                */
/*                                                                       */
/* Called By: r_dw_delivery_note15_rdt                                   */
/*                                                                       */
/* PVCS Version: 1.1                                                     */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author  Ver   Purposes                                   */
/*************************************************************************/
CREATE PROC [dbo].[isp_CC_Sheet_Summary01] (
@c_ccKey NVARCHAR(10),
@c_DWCategory  NVARCHAR(1) = 'H',
@c_ccsheetStart NVARCHAR(10) = '0',
@c_ccsheetEnd   NVARCHAR(10) = 'ZZZZZZZ',
@c_Noofpage    NVARCHAR(5)         = '1'
)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @c_Category NVARCHAR(1),
           @n_noofpage  INT,
           @c_col01     NVARCHAR(10),
           @c_col02     NVARCHAR(10)
   
   
   CREATE TABLE #TMP_CCSummary (
      	SeqNo       INT IDENTITY (1,1),
      	Col01       NVARCHAR(10) DEFAULT(''),
      	Col02       NVARCHAR(10) DEFAULT(''),
      	ccsheetStart NVARCHAR(5)  DEFAULT(''),
      	ccsheetEnd   NVARCHAR(10) DEFAULT(''),
      	Noofpage     NVARCHAR(5)  DEFAULT(''),
      	DWCategory  NVARCHAR(1)
   )
   
   SET @c_Category = ''
   
   SET @n_noofpage = CONVERT(INT,@c_Noofpage)
   
   IF @c_DWCategory = 'P'
   BEGIN
   	SET @c_Category='B'
   END
   ELSE IF @c_DWCategory = 'B'
   BEGIN
   	SET @c_Category='H'
   END
   ELSE
   	BEGIN
   		SET @c_Category=@c_DWCategory
   	END
       
   IF @c_DWCategory = 'D'
   BEGIN
      GOTO Detail
   END

   HEADER:
      
   INSERT INTO #TMP_CCSummary (Col01,col02,DWCategory,ccsheetStart,ccsheetEnd,Noofpage)
   SELECT DISTINCT CCDETAIL.CCKEY,CCDETAIL.CCKEY,@c_Category,@c_ccsheetStart,@c_ccsheetEnd,@c_Noofpage
   FROM CCDETAIL (NOLOCK) 
   WHERE CCDETAIL.CCKEY = @c_ccKey
  
  WHILE @n_Noofpage <> 1
  BEGIN
  	INSERT INTO #TMP_CCSummary (Col01,col02,DWCategory)
  	SELECT TOP 1 col01,Col02,DWCategory
  	FROM #TMP_CCSummary
  	WHERE col01 = @c_ccKey
  	
  	SET @n_Noofpage = @n_Noofpage - 1

  END
  
  IF @c_DWCategory IN ('H')
  BEGIN
	  SELECT Col01,Col02,DWCategory
	  FROM  #TMP_CCSummary
	  WHERE Col01 = @c_ccKey
	 
	  GOTO QUIT_SP 
  END
  ELSE IF @c_DWCategory IN ('P')
  BEGIN
	  SELECT Col01,Col02,DWCategory,@c_ccsheetStart,@c_ccsheetEnd,@c_Noofpage
	  FROM  #TMP_CCSummary
	  WHERE Col01 = @c_ccKey
	 
	  GOTO QUIT_SP 
  END
  ELSE
  IF @c_DWCategory = 'B'
   BEGIN
      GOTO Detail
   END
  
  DETAIL:

  CREATE TABLE #TMP_CCDETAIL
  (SeqNo       INT IDENTITY (1,1),
   CCSheetNo   NVARCHAR(10),
   DWCategory  NVARCHAR(1)  
  	)
  
   INSERT INTO #TMP_CCSummary (Col01,col02,DWCategory)
   SELECT DISTINCT CCDETAIL.CCKEY,CCDETAIL.CCSheetNo,'D'
   FROM CCDETAIL (NOLOCK) 
   WHERE CCDETAIL.CCKEY = @c_ccKey
   AND CCSheetNo > = @c_ccsheetStart
   AND CCSheetNo < = @c_ccsheetEND
   
   
  WHILE @n_Noofpage <> 1
  BEGIN
  	DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
  	SELECT DISTINCT Col01,Col02
  	FROM #TMP_CCSummary AS tc
  	WHERE COL01=@c_ccKey
  	
  	OPEN CUR_LOOP   
     
   FETCH NEXT FROM CUR_LOOP INTO @c_Col01,@c_Col02    
     
   WHILE @@FETCH_STATUS <> -1  
   BEGIN   
  	
  	INSERT INTO #TMP_CCSummary (Col01,col02,DWCategory)
  	SELECT TOP 1 col01,Col02,DWCategory
  	FROM #TMP_CCSummary
   WHERE Col01 = @c_Col01
   AND Col02 = @c_col02
   AND DWCategory='D'
   
   FETCH NEXT FROM CUR_LOOP INTO @c_Col01,@c_col02   
   END   
   
  CLOSE CUR_LOOP  
  DEALLOCATE CUR_LOOP   
  	
  	SET @n_Noofpage = @n_Noofpage - 1

  END
   
   
   SELECT col01,Col02,DWCategory 
   FROM #TMP_CCSummary
   WHERE Col01= @c_ccKey
   ORDER BY DWCategory desc,Col01,Col02
  
  GOTO QUIT_SP
  
  
   DROP TABLE #TMP_CCSummary
   --DROP TABLE #TMP_CCDETAIL
  QUIT_SP:
END




GO