SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: isp_LotxLocxID_Lot_LA                                       */
/* Creation Date: 23-MAR-2016                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: SOS#365940 - FBR365940_SG_SHOW_PICKS                        */
/*        :                                                             */
/* Called By:  d_dddw_lotxlocxid_lot_la                                 */
/*          :                                                           */
/* PVCS Version: 1.4                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 15-Mar-2018 SWT01    1.1   Assign Column Name to Result              */
/* 27-Oct-2020 WLChooi  1.2   WMS-15498 - Add Lottable01-05 (WL01)      */
/* 26-Nov-2021 Mingle    1.3 WMS-18349 - Add Status (ML01)             */
/* 26-Nov-2021 Mingle   1.3   DevOps Combine Script                     */
/* 31-Mar-2023 Wan01    1.4   LFWM-4059 - PROD CN Pick Management LOT   */
/*                            sorting and filter of all the detail fields*/
/*                            is invalid, like Lottable03               */
/* 09-May-2023 CheeMunSim    1.5   LFWM-4286 - UAT & PROD CN Pick Management LOT   */
/*                                 enable values for columns from lottable06       */
/*                                 to lottable15       */
/************************************************************************/
CREATE   PROC [dbo].[isp_LotxLocxID_Lot_LA] 
   @c_StorerKey         NVARCHAR(15)
 , @c_SKU               NVARCHAR(20)
 , @c_Facility          NVARCHAR(5) 
 , @c_Lottable01        NVARCHAR(18) = ''
 , @c_Lottable02        NVARCHAR(18) = ''
 , @c_Lottable03        NVARCHAR(18) = ''
 , @d_Lottable04        DATETIME  = NULL   
 , @d_Lottable05        DATETIME  = NULL   
 , @c_lottable06        NVARCHAR(30) = '' 
 , @c_lottable07        NVARCHAR(30) = '' 
 , @c_lottable08        NVARCHAR(30) = '' 
 , @c_lottable09        NVARCHAR(30) = '' 
 , @c_lottable10        NVARCHAR(30) = '' 
 , @c_lottable11        NVARCHAR(30) = '' 
 , @c_lottable12        NVARCHAR(30) = '' 
 , @d_lottable13        DATETIME = NULL   
 , @d_lottable14        DATETIME = NULL   
 , @d_lottable15        DATETIME = NULL   
,  @c_SearchCondition   NVARCHAR(MAX)  = ''  --(Wan03) Search Condition from Actual WHERE result 
,  @c_SortPreference    NVARCHAR(MAX)  = ''  --(Wan03) Only sort column. Multiple Sort Columns are seperated to be , (comma)

AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 

   DECLARE @n_ForceLAEnable   INT
         , @c_ForceLAList     NVARCHAR(1000) 
         , @c_LAConditions    NVARCHAR(4000)
         , @c_SQL             NVARCHAR(MAX)
         
            
   IF OBJECT_ID('tempdb..#ReturnResult','u') IS NOT NULL          --(Wan03) - START
   BEGIN
      DROP TABLE #ReturnResult 
   END
   
   CREATE TABLE #ReturnResult                    
         (  Lot               NVARCHAR(10)   NOT NULL DEFAULT('')
         ,  [Status]          NVARCHAR(10)   NOT NULL DEFAULT('')
         ,  QtyAvailable      INT            NOT NULL DEFAULT(0)
         ,  Lottable01        NVARCHAR(18)   NOT NULL DEFAULT('')
         ,  Lottable02        NVARCHAR(18)   NOT NULL DEFAULT('')
         ,  Lottable03        NVARCHAR(18)   NOT NULL DEFAULT('')
         ,  Lottable04        NVARCHAR(24)   NULL   
         ,  Lottable05        NVARCHAR(24)   NULL        
         ,  Lottable06        NVARCHAR(30)   NOT NULL DEFAULT('') --(CheeMunSim) - 1.5 START
         ,  Lottable07        NVARCHAR(30)   NOT NULL DEFAULT('')
         ,  Lottable08        NVARCHAR(30)   NOT NULL DEFAULT('')
         ,  Lottable09        NVARCHAR(30)   NOT NULL DEFAULT('')
         ,  Lottable10        NVARCHAR(30)   NOT NULL DEFAULT('')
         ,  Lottable11        NVARCHAR(30)   NOT NULL DEFAULT('')
         ,  Lottable12        NVARCHAR(30)   NOT NULL DEFAULT('')
         ,  Lottable13        NVARCHAR(24)   NULL
         ,  Lottable14        NVARCHAR(24)   NULL
         ,  Lottable15        NVARCHAR(24)   NULL		 		  --(CheeMunSim) - 1.5 END		 
         )                                                        --(Wan03) - END
   
   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1


   SET @d_Lottable04 = CASE WHEN @d_Lottable04 = '1900-01-01' THEN NULL ELSE @d_Lottable04 END
   SET @d_Lottable05 = CASE WHEN @d_Lottable05 = '1900-01-01' THEN NULL ELSE @d_Lottable05 END
   SET @d_Lottable13 = CASE WHEN @d_Lottable13 = '1900-01-01' THEN NULL ELSE @d_Lottable13 END
   SET @d_Lottable14 = CASE WHEN @d_Lottable14 = '1900-01-01' THEN NULL ELSE @d_Lottable14 END
   SET @d_Lottable15 = CASE WHEN @d_Lottable15 = '1900-01-01' THEN NULL ELSE @d_Lottable15 END

   SET @n_ForceLAEnable= 0
   SET @c_ForceLAList  = ''
   SET @c_LAConditions = ' '

   SELECT TOP 1 @c_ForceLAList = NOTES
         , @n_ForceLAEnable = 1
   FROM CODELKUP WITH (NOLOCK)
   WHERE Storerkey = @c_StorerKey
   AND Listname = 'FORCEALLOT'
   AND (Short <> 'N' OR Short IS NULL)
   
   IF @n_ForceLAEnable = 1
   BEGIN
      IF ISNULL(RTRIM(@c_ForceLAList),'') IN ( '', 'ALL')
      BEGIN
         SET @c_ForceLAList = 'LOTTABLE01,LOTTABLE02,LOTTABLE03,LOTTABLE04,LOTTABLE05'
                            +',LOTTABLE06,LOTTABLE07,LOTTABLE08,LOTTABLE09,LOTTABLE10'
                            +',LOTTABLE11,LOTTABLE12,LOTTABLE13,LOTTABLE14,LOTTABLE15'
      END

      SET @c_LAConditions = @c_LAConditions 
                          + CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') <> '' AND CHARINDEX('LOTTABLE01', @c_ForceLAList) > 0 THEN 'AND LOTATTRIBUTE.Lottable01 = @c_Lottable01 ' END 
      SET @c_LAConditions = @c_LAConditions 
                          + CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') <> '' AND CHARINDEX('LOTTABLE02', @c_ForceLAList) > 0 THEN 'AND LOTATTRIBUTE.Lottable02 = @c_Lottable02 ' END 
      SET @c_LAConditions = @c_LAConditions 
                          + CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') <> '' AND CHARINDEX('LOTTABLE03', @c_ForceLAList) > 0 THEN 'AND LOTATTRIBUTE.Lottable03 = @c_Lottable03 ' END 
      SET @c_LAConditions = @c_LAConditions 
                          + CASE WHEN ISNULL(RTRIM(@d_Lottable04),'1900-01-01') <> '1900-01-01' AND CHARINDEX('LOTTABLE04', @c_ForceLAList) > 0 THEN 'AND LOTATTRIBUTE.Lottable04 = @d_Lottable04 ' END 
      SET @c_LAConditions = @c_LAConditions 
                          + CASE WHEN ISNULL(RTRIM(@d_Lottable05),'1900-01-01') <> '1900-01-01' AND CHARINDEX('LOTTABLE05', @c_ForceLAList) > 0 THEN 'AND LOTATTRIBUTE.Lottable05 = @d_Lottable05 ' END 
      SET @c_LAConditions = @c_LAConditions 
                          + CASE WHEN ISNULL(RTRIM(@c_Lottable06),'') <> '' AND CHARINDEX('LOTTABLE06', @c_ForceLAList) > 0 THEN 'AND LOTATTRIBUTE.Lottable06 = @c_Lottable06 ' END 
      SET @c_LAConditions = @c_LAConditions 
                          + CASE WHEN ISNULL(RTRIM(@c_Lottable07),'') <> '' AND CHARINDEX('LOTTABLE07', @c_ForceLAList) > 0 THEN 'AND LOTATTRIBUTE.Lottable07 = @c_Lottable07 ' END 
      SET @c_LAConditions = @c_LAConditions 
                          + CASE WHEN ISNULL(RTRIM(@c_Lottable08),'') <> '' AND CHARINDEX('LOTTABLE08', @c_ForceLAList) > 0 THEN 'AND LOTATTRIBUTE.Lottable08 = @c_Lottable08 ' END 
      SET @c_LAConditions = @c_LAConditions 
                          + CASE WHEN ISNULL(RTRIM(@c_Lottable09),'') <> '' AND CHARINDEX('LOTTABLE09', @c_ForceLAList) > 0 THEN 'AND LOTATTRIBUTE.Lottable09 = @c_Lottable09 ' END 
      SET @c_LAConditions = @c_LAConditions 
                          + CASE WHEN ISNULL(RTRIM(@c_Lottable10),'') <> '' AND CHARINDEX('LOTTABLE10', @c_ForceLAList) > 0 THEN 'AND LOTATTRIBUTE.Lottable10 = @c_Lottable10 ' END 
      SET @c_LAConditions = @c_LAConditions 
                          + CASE WHEN ISNULL(RTRIM(@c_Lottable11),'') <> '' AND CHARINDEX('LOTTABLE11', @c_ForceLAList) > 0 THEN 'AND LOTATTRIBUTE.Lottable11 = @c_Lottable11 ' END 
      SET @c_LAConditions = @c_LAConditions 
                          + CASE WHEN ISNULL(RTRIM(@c_Lottable12),'') <> '' AND CHARINDEX('LOTTABLE12', @c_ForceLAList) > 0 THEN 'AND LOTATTRIBUTE.Lottable12 = @c_Lottable12 ' END
      SET @c_LAConditions = @c_LAConditions 
                          + CASE WHEN ISNULL(RTRIM(@d_Lottable13),'1900-01-01') <> '1900-01-01' AND CHARINDEX('LOTTABLE13', @c_ForceLAList) > 0 THEN 'AND LOTATTRIBUTE.Lottable13 = @d_Lottable13 ' END 
      SET @c_LAConditions = @c_LAConditions 
                          + CASE WHEN ISNULL(RTRIM(@d_Lottable14),'1900-01-01') <> '1900-01-01' AND CHARINDEX('LOTTABLE14', @c_ForceLAList) > 0 THEN 'AND LOTATTRIBUTE.Lottable14 = @d_Lottable14 ' END 
      SET @c_LAConditions = @c_LAConditions 
                          + CASE WHEN ISNULL(RTRIM(@d_Lottable15),'1900-01-01') <> '1900-01-01' AND CHARINDEX('LOTTABLE15', @c_ForceLAList) > 0 THEN 'AND LOTATTRIBUTE.Lottable15 = @d_Lottable15 ' END 
   END
   
   SET @c_SQL  = N' SELECT LOTxLOCxID.Lot'   
               +       ' , SUM(LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated- LOTxLOCxID.QtyPicked) AS QtyAvailable ' -- SWT01
               +       ' , LOTATTRIBUTE.Lottable01, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable03'
               +       ' , CONVERT(NVARCHAR(24),LOTATTRIBUTE.Lottable04,121) AS Lottable04' --(Wan03)
               +       ' , CONVERT(NVARCHAR(24),LOTATTRIBUTE.Lottable05,121) AS Lottable05' --(Wan03) --WL01
               +       ' , CASE WHEN (LOT.Status = ''HOLD'') THEN ''HOLD (LOT)'' '    --START ML01
               +       '        WHEN (LOC.LocationFlag = ''HOLD'' OR LOC.LocationFlag = ''DAMAGE'') THEN ''HOLD (LOC)'' '
               +       '        WHEN (LOC.Status = ''HOLD'') THEN ''HOLD (LOC)''  '
               +       '        WHEN (ID.Status = ''HOLD'') THEN ''HOLD (ID)'' '
               +       '        ELSE ''OK'' END as Status '                           --END ML01
			   			   +       ' , LOTATTRIBUTE.Lottable06, LOTATTRIBUTE.Lottable07, LOTATTRIBUTE.Lottable08' --(CheeMunSim) 1.5
			   +       ' , LOTATTRIBUTE.Lottable09, LOTATTRIBUTE.Lottable10, LOTATTRIBUTE.Lottable11' --(CheeMunSim) 1.5
			   +       ' , LOTATTRIBUTE.Lottable12'													  --(CheeMunSim) 1.5
               +       ' , CONVERT(NVARCHAR(24),LOTATTRIBUTE.Lottable13,121) AS Lottable13' 		  --(CheeMunSim) 1.5
			   +       ' , CONVERT(NVARCHAR(24),LOTATTRIBUTE.Lottable14,121) AS Lottable14' 		  --(CheeMunSim) 1.5
			   +       ' , CONVERT(NVARCHAR(24),LOTATTRIBUTE.Lottable15,121) AS Lottable15' 		  --(CheeMunSim) 1.5
               +  ' FROM LOTxLOCxID WITH (NOLOCK)'
               +  ' JOIN LOTATTRIBUTE WITH (NOLOCK) ON (LOTxLOCxID.Lot = LOTATTRIBUTE.Lot)'
               +  ' JOIN LOC WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.Loc)'
               +  ' JOIN LOT WITH (NOLOCK) ON (LOTxLOCxID.Lot = LOT.Lot)'     --ML01
               +  ' JOIN ID WITH (NOLOCK) ON (LOTxLOCxID.ID = ID.ID)'         --ML01
               +  ' WHERE LOTxLOCxID.Storerkey = @c_Storerkey'
               +  ' AND LOTxLOCxID.Sku = @c_Sku'
               +  ' AND LOC.Facility = @c_Facility'
               +  ' AND (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated- LOTxLOCxID.QtyPicked) > 0'
               +  @c_LAConditions
               +  ' GROUP BY LOTxLOCxID.Lot'
               +       '   ,LOTATTRIBUTE.Lottable01, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable03, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05'   --WL01
               +       '   ,CASE WHEN (LOT.Status = ''HOLD'') THEN ''HOLD (LOT)'' '    --START ML01
               +       '         WHEN (LOC.LocationFlag = ''HOLD'' OR LOC.LocationFlag = ''DAMAGE'') THEN ''HOLD (LOC)'' '
               +       '         WHEN (LOC.Status = ''HOLD'') THEN ''HOLD (LOC)''  '
               +       '         WHEN (ID.Status = ''HOLD'') THEN ''HOLD (ID)'' '
               +       '         ELSE ''OK'' END '                                     --END ML01
			   +       '   ,LOTATTRIBUTE.Lottable06, LOTATTRIBUTE.Lottable07, LOTATTRIBUTE.Lottable08, LOTATTRIBUTE.Lottable09, LOTATTRIBUTE.Lottable10'   --(CheeMunSim) 1.5
			   +       '   ,LOTATTRIBUTE.Lottable11, LOTATTRIBUTE.Lottable12, LOTATTRIBUTE.Lottable13, LOTATTRIBUTE.Lottable14, LOTATTRIBUTE.Lottable15'   --(CheeMunSim) 1.5

   INSERT INTO #ReturnResult                    --(Wan03)
      (Lot, QtyAvailable, Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, [Status], Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, Lottable11, Lottable12, Lottable13, Lottable14, Lottable15) --(CheeMunSim) 1.5  
   EXEC SP_ExecuteSQL @c_SQL
               ,N'@c_Storerkey  NVARCHAR(15)
                 ,@c_Sku         NVARCHAR(20)    
                 ,@c_Facility    NVARCHAR(5)  
                 ,@c_Lottable01  NVARCHAR(18)
                 ,@c_Lottable02  NVARCHAR(18)
                 ,@c_Lottable03  NVARCHAR(18)
                 ,@d_Lottable04  DATETIME    
                 ,@d_Lottable05  DATETIME    
                 ,@c_lottable06  NVARCHAR(30)
                 ,@c_lottable07  NVARCHAR(30)
                 ,@c_lottable08  NVARCHAR(30)
                 ,@c_lottable09  NVARCHAR(30)
                 ,@c_lottable10  NVARCHAR(30)
                 ,@c_lottable11  NVARCHAR(30)
                 ,@c_lottable12  NVARCHAR(30)
                 ,@d_lottable13  DATETIME    
                 ,@d_lottable14  DATETIME    
                 ,@d_lottable15  DATETIME'    
               , @c_Storerkey  
               , @c_Sku        
               , @c_Facility   
               , @c_Lottable01 
               , @c_Lottable02 
               , @c_Lottable03 
               , @d_Lottable04 
               , @d_Lottable05 
               , @c_lottable06 
               , @c_lottable07 
               , @c_lottable08 
               , @c_lottable09 
               , @c_lottable10 
               , @c_lottable11 
               , @c_lottable12 
               , @d_lottable13 
               , @d_lottable14 
               , @d_lottable15 

   --(Wan03) - START
   IF @c_SearchCondition <> ''
   BEGIN
      SET @c_SearchCondition =  ' WHERE ' + @c_SearchCondition
   END
         
   SET @c_SortPreference = ISNULL(@c_SortPreference,'')           
   IF @c_SortPreference = ''
   BEGIN
      SET @c_SortPreference = N' ORDER BY Lot ASC'
   END
   ELSE 
   BEGIN
      SET @c_SortPreference = N' ORDER BY ' +  @c_SortPreference 
   END
   
   SET @c_SQL  = N'SELECT Lot'
               + ', QtyAvailable'
               + ', Lottable01'  
               + ', Lottable02'   
               + ', Lottable03'   
               + ', Lottable04 = CONVERT(DATETIME, Lottable04)'  
               + ', Lottable05 = CONVERT(DATETIME, Lottable05)' 
               + ', [Status]'  
               + ', Lottable06'									--(CheeMunSim) 1.5
               + ', Lottable07'									--(CheeMunSim) 1.5
               + ', Lottable08'									--(CheeMunSim) 1.5
               + ', Lottable09'									--(CheeMunSim) 1.5
               + ', Lottable10'									--(CheeMunSim) 1.5		
               + ', Lottable11'									--(CheeMunSim) 1.5
               + ', Lottable12'									--(CheeMunSim) 1.5
               + ', Lottable13 = CONVERT(DATETIME, Lottable13)' --(CheeMunSim) 1.5 
               + ', Lottable14 = CONVERT(DATETIME, Lottable14)' --(CheeMunSim) 1.5
               + ', Lottable15 = CONVERT(DATETIME, Lottable15)' --(CheeMunSim) 1.5				   
               + ' FROM #ReturnResult' 
               + @c_SearchCondition
               + @c_SortPreference  
                    
   EXEC sp_ExecuteSQL @c_SQL
   --(Wan03) - END         
   QUIT:
   IF OBJECT_ID('tempdb..#ReturnResult','u') IS NOT NULL          --(Wan03) - START
   BEGIN
      DROP TABLE #ReturnResult 
   END                                                            --(Wan03) - END
END -- procedure

GO