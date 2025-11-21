SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: ispSEPCDB2B                                             */  
/* Creation Date: 2021-08-19                                            */  
/* Copyright: LF Logistics                                              */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose: WMS-17723 - CN_Sephora Chengdu_WMS_AllocationStrategy       */  
/*        :                                                             */  
/* Called By:                                                           */  
/*          :                                                           */  
/* GitLab Version: 1.2                                                  */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author  Ver   Purposes                                  */
/* 19-Aug-2021  WLChooi 1.0   DevOps Combine Script                     */
/* 29-Apr-2022  WLChooi 1.1   Performance Tuning - Create new TRAN      */
/*                            before executing sub-sp & commit the TRAN */
/*                            after execution complete (WL01)           */
/* 14-NOV-2022  Wan01   1.2   Sync filter Start Point/Enhancement       */
/************************************************************************/  
CREATE PROC [dbo].[ispSEPCDB2B]
     @c_WaveKey                     NVARCHAR(10)  
   , @c_UOM                         NVARCHAR(10)  
   , @c_LocationTypeOverride        NVARCHAR(10)  
   , @c_LocationTypeOverRideStripe  NVARCHAR(10)  
   , @b_Success                     INT           OUTPUT    
   , @n_Err                         INT           OUTPUT    
   , @c_ErrMsg                      NVARCHAR(255) OUTPUT    
   , @b_Debug                       INT = 0  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE    
           @n_StartTCnt          INT   = @@TRANCOUNT  
         , @n_Continue           INT   = 1  
  
         , @n_MinShelfLife       INT   = 0  
         , @c_WaveType           NVARCHAR(10) = ''  
  
         , @c_Facility           NVARCHAR(5)  = ''  
         , @c_Storerkey          NVARCHAR(15) = ''  
         , @c_Sku                NVARCHAR(20) = ''  
         , @c_Lottable01         NVARCHAR(18) = ''        
         , @c_Lottable02         NVARCHAR(18) = ''     
         , @c_Lottable03         NVARCHAR(18) = ''  
         , @dt_Lottable04        DATETIME   
         , @dt_Lottable05        DATETIME       
    
         , @c_Lottable06         NVARCHAR(30) = ''  
         , @c_Lottable07         NVARCHAR(30) = ''  
         , @c_Lottable08         NVARCHAR(30) = ''  
         , @c_Lottable09         NVARCHAR(30) = ''  
         , @c_Lottable10         NVARCHAR(30) = ''  
         , @c_Lottable11         NVARCHAR(30) = ''  
         , @c_Lottable12         NVARCHAR(30) = ''  
         , @dt_Lottable13        DATETIME       
         , @dt_Lottable14        DATETIME  
         , @dt_Lottable15        DATETIME  
         , @dt_InvLot04          DATETIME  
         , @d_today              DATETIME = CONVERT(NVARCHAR(10), GETDATE(), 121)  
  
         , @n_QtyLeftToFullFill  INT          = 0  
           
         , @c_LocationCategory   NVARCHAR(10) = ''
  
         , @c_SQL                NVARCHAR(4000) = ''  
         , @c_SQLParms           NVARCHAR(4000) = ''  
  
         , @CUR_WVSKU            CURSOR  
         , @CUR_LOT04            CURSOR  
  
   SET @b_Success  = 1           
   SET @n_err      = 0  
   SET @c_errmsg  = ''  

   SELECT TOP 1 @c_WaveType = DispatchPiecePickMethod  
   FROM WAVE WITH (NOLOCK)  
   WHERE Wavekey = @c_Wavekey  
  
   IF @c_WaveType NOT IN ('SEPB2BPTS','SEPB2BNOR','SEPB2CALL')
   BEGIN  
      SET @n_Err = 82010  
      SET @n_Continue = 3  
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))    
                    + ': Invalid Wave Piece Pick Task Dispatch Method'  
                    + '. Must Be SEPB2BPTS, SEPB2BNOR or SEPB2CALL (ispSEPCDB2B)'
      GOTO QUIT_SP  
   END  
  
   IF @c_WaveType NOT IN ('SEPB2BPTS','SEPB2BNOR')  
   BEGIN  
      GOTO QUIT_SP  
   END  
  
   IF EXISTS ( SELECT 1   
               FROM WAVEDETAIL WD WITH (NOLOCK)  
               LEFT JOIN LOADPLANDETAIL LPD WITH (NOLOCK) ON WD.Orderkey = LPD.Orderkey  
               WHERE WD.Wavekey = @c_Wavekey  
               AND LPD.Loadkey IS NULL  
               )  
   BEGIN  
      SET @n_Err = 81011  
      SET @n_Continue = 3  
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))    
                    + ': Wave has not generate Loadplan yet'  
                    + '. Allocation is not allowed (ispSEPCDB2B)'  
      GOTO QUIT_SP  
   END  

   --WL01 S
   WHILE @@TRANCOUNT > 0 
   BEGIN
      COMMIT TRAN
   END
   --WL01 E
  
   IF OBJECT_ID('tempdb..#LOT04','U') IS NOT NULL  
   BEGIN  
      DROP TABLE #LOT04;  
   END  
  
   CREATE TABLE #LOT04  
      (  RowID          INT            IDENTITY(1,1) PRIMARY KEY  
      ,  ExpiryDate     DATETIME       NULL  
      )  
  
   SET @CUR_WVSKU = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT OH.Facility  
         ,OD.Storerkey  
         ,OD.Sku  
         ,OD.Lottable01  
         ,OD.Lottable02  
         ,OD.Lottable03  
         ,OD.Lottable06  
         ,OD.Lottable07  
         ,OD.Lottable08  
         ,OD.Lottable09  
         ,OD.Lottable10  
         ,OD.Lottable11  
         ,OD.Lottable12  
         ,Lottable13 = ISNULL(OD.Lottable13,'1900-01-01')  
         ,ISNULL(SUM(OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked )),0)  
         ,MinShelfLife = ISNULL(MIN(OD.MinShelfLife),0)   
                       + ISNULL(MIN( CASE WHEN ISNUMERIC(OIF.OrderInfo04) = 1   
                                          THEN CONVERT(INT,OIF.OrderInfo04)   
                                          ELSE 0   
                                          END  
                                   ),0)  
   FROM WAVE        WH WITH (NOLOCK)  
   JOIN WAVEDETAIL  WD WITH (NOLOCK) ON WH.Wavekey = WD.Wavekey  
   JOIN ORDERS      OH WITH (NOLOCK) ON WD.Orderkey = OH.Orderkey  
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON OH.Orderkey = OD.Orderkey  
   LEFT OUTER JOIN ORDERINFO OIF WITH (NOLOCK) ON OH.Orderkey = OIF.Orderkey  
   WHERE WH.Wavekey = @c_WaveKey  
     AND OH.Type NOT IN ( 'M', 'I' )     
     AND OH.SOStatus <> 'CANC'     
     AND OH.Status < '9'     
     AND (OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked )) > 0  
   GROUP BY OH.Facility  
         ,  OD.Storerkey  
         ,  OD.Sku  
         ,  OD.Lottable01  
         ,  OD.Lottable02  
         ,  OD.Lottable03  
         ,  OD.Lottable06  
         ,  OD.Lottable07  
         ,  OD.Lottable08  
         ,  OD.Lottable09  
         ,  OD.Lottable10  
         ,  OD.Lottable11  
         ,  OD.Lottable12  
         ,  ISNULL(OD.Lottable13,'1900-01-01')  
   HAVING SUM(OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked )) > 0  
  
   OPEN @CUR_WVSKU  
     
   FETCH NEXT FROM @CUR_WVSKU INTO  @c_Facility  
                                 ,  @c_Storerkey           
                                 ,  @c_Sku                 
                                 ,  @c_Lottable01                
                                 ,  @c_Lottable02             
                                 ,  @c_Lottable03          
                                 ,  @c_Lottable06          
                                 ,  @c_Lottable07          
                                 ,  @c_Lottable08          
                                 ,  @c_Lottable09          
                                 ,  @c_Lottable10          
                                 ,  @c_Lottable11          
                                 ,  @c_Lottable12          
                                 ,  @dt_Lottable13   
                                 ,  @n_QtyLeftToFullFill  
                                 ,  @n_MinShelfLife  
   
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
      TRUNCATE TABLE #LOT04;  
      SET @c_SQL = N'INSERT INTO #LOT04 ( ExpiryDate )'         
   + ' SELECT ExpiryDate = LA.Lottable04'                                     
   + ' FROM LOTxLOCxID LLI  WITH (NOLOCK)'  
   + ' JOIN LOT             WITH (NOLOCK) ON LLI.Lot = LOT.Lot AND LOT.[Status] = ''OK'''  
   + ' JOIN LOC             WITH (NOLOCK) ON LLI.Loc = LOC.Loc AND LOC.[Status] = ''OK'''  
   + ' JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON LLI.Lot = LA.Lot'   
   + ' WHERE LA.Storerkey = @c_Storerkey'             --(Wan01)  
   + ' AND   LA.Sku       = @c_Sku'                   --(Wan01)
   + CASE WHEN ISNULL(@c_Lottable01,'') = '' THEN '' ELSE ' AND LA.Lottable01 = @c_Lottable01' END  
   + CASE WHEN ISNULL(@c_Lottable02,'') = '' THEN '' ELSE ' AND LA.Lottable02 = @c_Lottable02' END  
   + CASE WHEN ISNULL(@c_Lottable03,'') = '' THEN '' ELSE ' AND LA.Lottable03 = @c_Lottable03' END  
   + CASE WHEN ISNULL(@c_Lottable06,'') = '' THEN '' ELSE ' AND LA.Lottable06 = @c_Lottable06' END  
   + CASE WHEN ISNULL(@c_Lottable07,'') = '' THEN '' ELSE ' AND LA.Lottable07 = @c_Lottable07' END  
   + CASE WHEN ISNULL(@c_Lottable08,'') = '' THEN '' ELSE ' AND LA.Lottable08 = @c_Lottable08' END  
   + CASE WHEN ISNULL(@c_Lottable09,'') = '' THEN '' ELSE ' AND LA.Lottable09 = @c_Lottable09' END  
   + CASE WHEN ISNULL(@c_Lottable10,'') = '' THEN '' ELSE ' AND LA.Lottable10 = @c_Lottable10' END  
   + CASE WHEN ISNULL(@c_Lottable11,'') = '' THEN '' ELSE ' AND LA.Lottable11 = @c_Lottable11' END  
   + CASE WHEN ISNULL(@c_Lottable12,'') = '' THEN '' ELSE ' AND LA.Lottable12 = @c_Lottable12' END  
   + CASE WHEN ISNULL(@dt_Lottable13,'1900-01-01') = '1900-01-01' THEN '' ELSE ' AND LA.Lottable13 = @dt_Lottable13' END  
   +' AND   LOC.Facility  = @c_Facility'  
   +' AND   LOC.LocationCategory IN (''BULK'',''SHELVING'',''AVG'')'  
   +' AND   LOC.LocationType IN (''OTHER'',''DYNPPICK'',''PICK'')'  
   +' AND   LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked > 0'  
   +' AND   DATEDIFF(day, @d_today, LA.Lottable04) >= @n_MinShelfLife'  
   +' GROUP BY LA.Lottable04'                                
   +' ORDER BY LA.Lottable04'  
     
      SET @c_SQLParms  = N' @c_Facility           NVARCHAR(5)'    
                       + ', @c_Storerkey          NVARCHAR(15)'   
                       + ', @c_Sku                NVARCHAR(20)'   
                       + ', @c_Lottable01         NVARCHAR(18)'       
                       + ', @c_Lottable02         NVARCHAR(18)'    
                       + ', @c_Lottable03         NVARCHAR(18)'   
                       + ', @c_Lottable06         NVARCHAR(30)'   
                       + ', @c_Lottable07         NVARCHAR(30)'   
                       + ', @c_Lottable08         NVARCHAR(30)'   
                       + ', @c_Lottable09         NVARCHAR(30)'   
                       + ', @c_Lottable10         NVARCHAR(30)'   
                       + ', @c_Lottable11         NVARCHAR(30)'   
                       + ', @c_Lottable12         NVARCHAR(30)'   
                       + ', @dt_Lottable13        DATETIME'    
                       + ', @d_today              DATETIME'  
                       + ', @n_MinShelfLife       INT'            
        
       EXEC sp_ExecuteSQL  @c_SQL  
                         , @c_SQLParms   
                         , @c_Facility             
                         , @c_Storerkey           
                         , @c_Sku                 
                         , @c_Lottable01          
                         , @c_Lottable02          
                         , @c_Lottable03          
                         , @c_Lottable06          
                         , @c_Lottable07          
                         , @c_Lottable08          
                         , @c_Lottable09          
                         , @c_Lottable10          
                         , @c_Lottable11          
                         , @c_Lottable12          
                         , @dt_Lottable13    
                         , @d_today   
                         , @n_MinShelfLife                
  
      SET @CUR_LOT04 = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT ExpiryDate  
      FROM #LOT04  
      ORDER BY RowID  
  
      OPEN @CUR_LOT04  
     
      FETCH NEXT FROM @CUR_LOT04 INTO  @dt_InvLot04  
   
      WHILE @@FETCH_STATUS <> -1 AND @n_QtyLeftToFullFill > 0  
      BEGIN  
         IF @b_debug IN (1,9)  
         BEGIN  
            PRINT '-----------------------------------'+ CHAR(13) +  
                  'Main PICKCOde: ispSEPCDB2B'+ CHAR(13) +  
                  'SKU: ' + @c_SKU + CHAR(13) +  
                  '@n_QtyLeftToFullFill: ' + CAST(@n_QtyLeftToFullFill AS VARCHAR) + CHAR(13) +  
                  '@dt_Lottable13: ' + CONVERT(NVARCHAR(25), @dt_Lottable13, 121) + CHAR(13) +   
                  '@dt_InvLot04: ' + CONVERT(NVARCHAR(25), @dt_InvLot04, 121) + CHAR(13)   
  
         END   
         
         BEGIN TRAN   --WL01

         EXEC ispSEPCDLoadFP2   --//Pallet @Pallet LOC  
           @c_WaveKey          = @c_WaveKey           
         , @c_WaveType         = @c_WaveType    
         , @c_Facility         = @c_Facility           
         , @c_Storerkey        = @c_Storerkey          
         , @c_Sku              = @c_Sku                
         , @c_Lottable01       = @c_Lottable01         
         , @c_Lottable02       = @c_Lottable02         
         , @c_Lottable03       = @c_Lottable03         
         , @dt_Lottable04      = @dt_Lottable04        
         , @dt_Lottable05      = @dt_Lottable05        
         , @c_Lottable06       = @c_Lottable06         
         , @c_Lottable07       = @c_Lottable07         
         , @c_Lottable08       = @c_Lottable08         
         , @c_Lottable09       = @c_Lottable09         
         , @c_Lottable10       = @c_Lottable10         
         , @c_Lottable11       = @c_Lottable11         
         , @c_Lottable12       = @c_Lottable12         
         , @dt_Lottable13      = @dt_Lottable13        
         , @dt_Lottable14      = @dt_Lottable14        
         , @dt_Lottable15      = @dt_Lottable15        
         , @dt_InvLot04        = @dt_InvLot04          
         , @n_QtyLeftToFullfill= @n_QtyLeftToFullfill OUTPUT  
         , @b_Success          = @b_Success           OUTPUT    
         , @n_Err              = @n_Err               OUTPUT    
         , @c_ErrMsg           = @c_ErrMsg            OUTPUT  
         , @b_Debug            = @b_Debug  
  
         IF @b_Success = 0   
         BEGIN  
            SET @n_Continue = 3  
            SET @n_Err = 82020  
            SET @c_ErrMsg = ISNULL(ERROR_MESSAGE(),'')  
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Error Executing ispSEPCDLoadFP2.'  
                           + '(ispSEPCDB2B)' + ' (' + @c_ErrMsg + ')' 
            ROLLBACK TRAN   --WL01               
            GOTO QUIT_SP  
         END  
         ELSE   --WL01 S
         BEGIN
            WHILE @@TRANCOUNT > 0
            BEGIN
               COMMIT TRAN
            END
         END
         --WL01 E
  
         IF @n_QtyLeftToFullfill <= 0  
         BEGIN  
            GOTO NEXT_INVLOT04  
         END  

         BEGIN TRAN   --WL01
  
         EXEC ispSEPCDLoadFC2   --//CASE @Case & @Pallet Loc, UOM = '2'  
           @c_WaveKey          = @c_WaveKey           
         , @c_WaveType         = @c_WaveType    
         , @c_Facility         = @c_Facility           
         , @c_Storerkey        = @c_Storerkey          
         , @c_Sku              = @c_Sku                
         , @c_Lottable01       = @c_Lottable01         
         , @c_Lottable02       = @c_Lottable02         
         , @c_Lottable03       = @c_Lottable03         
         , @dt_Lottable04      = @dt_Lottable04        
         , @dt_Lottable05      = @dt_Lottable05        
         , @c_Lottable06       = @c_Lottable06         
         , @c_Lottable07       = @c_Lottable07      
         , @c_Lottable08       = @c_Lottable08         
         , @c_Lottable09       = @c_Lottable09         
         , @c_Lottable10       = @c_Lottable10         
         , @c_Lottable11       = @c_Lottable11         
         , @c_Lottable12       = @c_Lottable12         
         , @dt_Lottable13      = @dt_Lottable13        
         , @dt_Lottable14      = @dt_Lottable14        
         , @dt_Lottable15      = @dt_Lottable15        
         , @dt_InvLot04        = @dt_InvLot04          
         , @n_QtyLeftToFullfill= @n_QtyLeftToFullfill OUTPUT  
         , @b_Success          = @b_Success           OUTPUT    
         , @n_Err              = @n_Err               OUTPUT    
         , @c_ErrMsg           = @c_ErrMsg            OUTPUT  
         , @b_Debug            = @b_Debug  
  
         IF @b_Success = 0   
         BEGIN  
            SET @n_Continue = 3  
            SET @n_Err = 82030  
            SET @c_ErrMsg = ISNULL(ERROR_MESSAGE(),'')  
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Error Executing ispSEPCDLoadFC2.'  
                           + '(ispSEPCDB2B)' + ' (' + @c_ErrMsg + ')'  
            ROLLBACK TRAN   --WL01
            GOTO QUIT_SP  
         END  
         ELSE   --WL01 S
         BEGIN
            WHILE @@TRANCOUNT > 0
            BEGIN
               COMMIT TRAN
            END
         END
         --WL01 E
  
         IF @n_QtyLeftToFullfill <= 0  
         BEGIN  
            GOTO NEXT_INVLOT04  
         END  
         
         BEGIN TRAN   --WL01

         EXEC ispSEPCDConsoFP6  --//Pallet @Pallet LOC  
           @c_WaveKey          = @c_WaveKey           
         , @c_WaveType         = @c_WaveType     
         , @c_Facility         = @c_Facility           
         , @c_Storerkey        = @c_Storerkey          
         , @c_Sku              = @c_Sku                
         , @c_Lottable01       = @c_Lottable01         
         , @c_Lottable02       = @c_Lottable02         
         , @c_Lottable03       = @c_Lottable03         
         , @dt_Lottable04      = @dt_Lottable04        
         , @dt_Lottable05      = @dt_Lottable05        
         , @c_Lottable06       = @c_Lottable06         
         , @c_Lottable07       = @c_Lottable07         
         , @c_Lottable08       = @c_Lottable08         
         , @c_Lottable09       = @c_Lottable09         
         , @c_Lottable10       = @c_Lottable10         
         , @c_Lottable11       = @c_Lottable11         
         , @c_Lottable12       = @c_Lottable12         
         , @dt_Lottable13      = @dt_Lottable13        
         , @dt_Lottable14      = @dt_Lottable14        
         , @dt_Lottable15      = @dt_Lottable15        
         , @dt_InvLot04        = @dt_InvLot04           
         , @n_QtyLeftToFullfill= @n_QtyLeftToFullfill OUTPUT  
         , @b_Success          = @b_Success           OUTPUT    
         , @n_Err              = @n_Err               OUTPUT    
         , @c_ErrMsg           = @c_ErrMsg            OUTPUT  
         , @b_Debug            = @b_Debug  
  
         IF @b_Success = 0   
         BEGIN  
            SET @n_Continue = 3  
            SET @n_Err = 82040  
            SET @c_ErrMsg = ISNULL(ERROR_MESSAGE(),'')  
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Error Executing ispSEPCDConsoFP6.'  
                           + '(ispSEPCDB2B)' + ' (' + @c_ErrMsg + ')'  
            ROLLBACK TRAN   --WL01
            GOTO QUIT_SP  
         END  
         ELSE   --WL01 S
         BEGIN
            WHILE @@TRANCOUNT > 0
            BEGIN
               COMMIT TRAN
            END
         END
         --WL01 E
  
         IF @n_QtyLeftToFullfill <= 0  
         BEGIN  
            GOTO NEXT_INVLOT04  
         END  
         
         BEGIN TRAN   --WL01

         EXEC ispSEPCDConsoFC6  --//CASE @Case & @Pallet Loc, UOM = '6'  
           @c_WaveKey          = @c_WaveKey           
         , @c_WaveType         = @c_WaveType     
         , @c_Facility         = @c_Facility           
         , @c_Storerkey        = @c_Storerkey          
         , @c_Sku              = @c_Sku                
         , @c_Lottable01       = @c_Lottable01         
         , @c_Lottable02       = @c_Lottable02         
         , @c_Lottable03       = @c_Lottable03         
         , @dt_Lottable04      = @dt_Lottable04        
         , @dt_Lottable05      = @dt_Lottable05        
         , @c_Lottable06       = @c_Lottable06         
         , @c_Lottable07       = @c_Lottable07         
         , @c_Lottable08       = @c_Lottable08         
         , @c_Lottable09       = @c_Lottable09         
         , @c_Lottable10       = @c_Lottable10         
         , @c_Lottable11       = @c_Lottable11         
         , @c_Lottable12       = @c_Lottable12         
         , @dt_Lottable13      = @dt_Lottable13        
         , @dt_Lottable14      = @dt_Lottable14        
         , @dt_Lottable15      = @dt_Lottable15        
         , @dt_InvLot04        = @dt_InvLot04           
         , @n_QtyLeftToFullfill= @n_QtyLeftToFullfill OUTPUT  
         , @b_Success          = @b_Success           OUTPUT    
         , @n_Err              = @n_Err               OUTPUT    
         , @c_ErrMsg           = @c_ErrMsg            OUTPUT  
         , @b_Debug            = @b_Debug  
  
         IF @b_Success = 0   
         BEGIN  
            SET @n_Continue = 3  
            SET @n_Err = 82050  
            SET @c_ErrMsg = ISNULL(ERROR_MESSAGE(),'')  
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Error Executing ispSEPCDConsoFC6.'  
                           + '(ispSEPCDB2B)' + ' (' + @c_ErrMsg + ')'  
            ROLLBACK TRAN   --WL01
            GOTO QUIT_SP  
         END  
         ELSE   --WL01 S
         BEGIN
            WHILE @@TRANCOUNT > 0
            BEGIN
               COMMIT TRAN
            END
         END
         --WL01 E
  
         IF @n_QtyLeftToFullfill <= 0  
         BEGIN  
            GOTO NEXT_INVLOT04  
         END  
         
         BEGIN TRAN   --WL01

         EXEC ispSEPCDConsoFQ7  --//Loose Qty @DPP Loc, UOM = '7', Get DPP > @n_QtyLeftToFullfill
           @c_WaveKey          = @c_WaveKey   
         , @c_WaveType         = @c_WaveType                        
         , @c_Facility         = @c_Facility           
         , @c_Storerkey        = @c_Storerkey          
         , @c_Sku              = @c_Sku                
         , @c_Lottable01       = @c_Lottable01         
         , @c_Lottable02       = @c_Lottable02         
         , @c_Lottable03       = @c_Lottable03         
         , @dt_Lottable04      = @dt_Lottable04        
         , @dt_Lottable05      = @dt_Lottable05        
         , @c_Lottable06       = @c_Lottable06         
         , @c_Lottable07       = @c_Lottable07         
         , @c_Lottable08       = @c_Lottable08         
         , @c_Lottable09       = @c_Lottable09         
         , @c_Lottable10       = @c_Lottable10         
         , @c_Lottable11       = @c_Lottable11         
         , @c_Lottable12       = @c_Lottable12         
         , @dt_Lottable13      = @dt_Lottable13        
         , @dt_Lottable14      = @dt_Lottable14        
         , @dt_Lottable15      = @dt_Lottable15        
         , @dt_InvLot04        = @dt_InvLot04           
         , @n_QtyLeftToFullfill= @n_QtyLeftToFullfill OUTPUT  
         , @b_Success          = @b_Success           OUTPUT    
         , @n_Err              = @n_Err               OUTPUT    
         , @c_ErrMsg           = @c_ErrMsg            OUTPUT  
         , @b_Debug            = @b_Debug  
  
         IF @b_Success = 0   
         BEGIN  
            SET @n_Continue = 3  
            SET @n_Err = 82060  
            SET @c_ErrMsg = ISNULL(ERROR_MESSAGE(),'')  
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Error Executing ispSEPCDConsoLQ7.'  
                           + '(ispSEPCDB2B)' + ' (' + @c_ErrMsg + ')'  
            ROLLBACK TRAN   --WL01
            GOTO QUIT_SP  
         END  
         ELSE   --WL01 S
         BEGIN
            WHILE @@TRANCOUNT > 0
            BEGIN
               COMMIT TRAN
            END
         END
         --WL01 E
  
         IF @n_QtyLeftToFullfill <= 0  
         BEGIN  
            GOTO NEXT_INVLOT04  
         END  
         
         BEGIN TRAN   --WL01

         EXEC ispSEPCDConsoLC7  --//Loose Qty @Case & @Pallet Loc, UOM = '7'  
           @c_WaveKey          = @c_WaveKey   
         , @c_WaveType         = @c_WaveType                      
         , @c_Facility         = @c_Facility           
         , @c_Storerkey        = @c_Storerkey          
         , @c_Sku              = @c_Sku                
         , @c_Lottable01       = @c_Lottable01         
         , @c_Lottable02       = @c_Lottable02         
         , @c_Lottable03       = @c_Lottable03         
         , @dt_Lottable04      = @dt_Lottable04        
         , @dt_Lottable05      = @dt_Lottable05        
         , @c_Lottable06       = @c_Lottable06         
         , @c_Lottable07       = @c_Lottable07         
         , @c_Lottable08       = @c_Lottable08         
         , @c_Lottable09       = @c_Lottable09         
         , @c_Lottable10       = @c_Lottable10         
         , @c_Lottable11       = @c_Lottable11         
         , @c_Lottable12       = @c_Lottable12         
         , @dt_Lottable13      = @dt_Lottable13        
         , @dt_Lottable14      = @dt_Lottable14        
         , @dt_Lottable15      = @dt_Lottable15        
         , @dt_InvLot04        = @dt_InvLot04           
         , @n_QtyLeftToFullfill= @n_QtyLeftToFullfill OUTPUT  
         , @b_Success          = @b_Success           OUTPUT    
         , @n_Err              = @n_Err               OUTPUT    
         , @c_ErrMsg           = @c_ErrMsg            OUTPUT  
         , @b_Debug            = @b_Debug  
  
         IF @b_Success = 0   
         BEGIN  
            SET @n_Continue = 3  
            SET @n_Err = 82070  
            SET @c_ErrMsg = ISNULL(ERROR_MESSAGE(),'')  
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Error Executing ispSEPCDConsoLC7.'  
                           + '(ispSEPCDB2B)' + ' (' + @c_ErrMsg + ')'  
            ROLLBACK TRAN   --WL01
            GOTO QUIT_SP  
         END 
         ELSE   --WL01 S
         BEGIN
            WHILE @@TRANCOUNT > 0
            BEGIN
               COMMIT TRAN
            END
         END
         --WL01 E

         IF @n_QtyLeftToFullfill <= 0  
         BEGIN  
            GOTO NEXT_INVLOT04  
         END  
         
         BEGIN TRAN   --WL01

         EXEC ispSEPCDConsoLQ7  --//Loose Qty @DPP Loc, UOM = '7', Get DPP >= 0   
           @c_WaveKey          = @c_WaveKey   
         , @c_WaveType         = @c_WaveType                        
         , @c_Facility         = @c_Facility           
         , @c_Storerkey        = @c_Storerkey          
         , @c_Sku              = @c_Sku                
         , @c_Lottable01       = @c_Lottable01         
         , @c_Lottable02       = @c_Lottable02         
         , @c_Lottable03       = @c_Lottable03         
         , @dt_Lottable04      = @dt_Lottable04        
         , @dt_Lottable05      = @dt_Lottable05        
         , @c_Lottable06       = @c_Lottable06         
         , @c_Lottable07       = @c_Lottable07         
         , @c_Lottable08       = @c_Lottable08         
         , @c_Lottable09       = @c_Lottable09         
         , @c_Lottable10       = @c_Lottable10         
         , @c_Lottable11       = @c_Lottable11         
         , @c_Lottable12       = @c_Lottable12         
         , @dt_Lottable13      = @dt_Lottable13        
         , @dt_Lottable14      = @dt_Lottable14        
         , @dt_Lottable15      = @dt_Lottable15        
         , @dt_InvLot04        = @dt_InvLot04           
         , @n_QtyLeftToFullfill= @n_QtyLeftToFullfill OUTPUT  
         , @b_Success          = @b_Success           OUTPUT    
         , @n_Err              = @n_Err               OUTPUT    
         , @c_ErrMsg           = @c_ErrMsg            OUTPUT  
         , @b_Debug            = @b_Debug  
  
         IF @b_Success = 0   
         BEGIN  
            SET @n_Continue = 3  
            SET @n_Err = 82075  
            SET @c_ErrMsg = ISNULL(ERROR_MESSAGE(),'')  
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Error Executing ispSEPCDConsoLQ7.'  
                           + '(ispSEPCDB2B)' + ' (' + @c_ErrMsg + ')'  
            ROLLBACK TRAN   --WL01
            GOTO QUIT_SP  
         END  
         ELSE   --WL01 S
         BEGIN
            WHILE @@TRANCOUNT > 0
            BEGIN
               COMMIT TRAN
            END
         END
         --WL01 E
  
         IF @b_debug IN (1,9)  
         BEGIN  
            PRINT '-----------------------------------'+ CHAR(13)  
         END  
  
         NEXT_INVLOT04:  
         FETCH NEXT FROM @CUR_LOT04 INTO @dt_InvLot04  
      END  
      CLOSE @CUR_LOT04  
      DEALLOCATE @CUR_LOT04  
  
      IF @n_QtyLeftToFullfill > 0  
      BEGIN  
         BEGIN TRAN   --WL01

         EXEC ispSEPCDConsoLQ7  --//Loose Qty UOM = '7'  
           @c_WaveKey          = @c_WaveKey   
         , @c_WaveType         = @c_WaveType                        
         , @c_Facility         = @c_Facility           
         , @c_Storerkey        = @c_Storerkey          
         , @c_Sku              = @c_Sku                
         , @c_Lottable01       = @c_Lottable01         
         , @c_Lottable02       = @c_Lottable02         
         , @c_Lottable03       = @c_Lottable03         
         , @dt_Lottable04      = @dt_Lottable04        
         , @dt_Lottable05      = @dt_Lottable05        
         , @c_Lottable06       = @c_Lottable06         
         , @c_Lottable07       = @c_Lottable07         
         , @c_Lottable08       = @c_Lottable08         
         , @c_Lottable09       = @c_Lottable09         
         , @c_Lottable10       = @c_Lottable10         
         , @c_Lottable11       = @c_Lottable11         
         , @c_Lottable12       = @c_Lottable12         
         , @dt_Lottable13      = @dt_Lottable13        
         , @dt_Lottable14      = @dt_Lottable14        
         , @dt_Lottable15      = @dt_Lottable15        
         , @dt_InvLot04        = NULL           
         , @n_QtyLeftToFullfill= @n_QtyLeftToFullfill OUTPUT  
         , @b_Success          = @b_Success           OUTPUT    
         , @n_Err              = @n_Err               OUTPUT    
         , @c_ErrMsg           = @c_ErrMsg            OUTPUT  
         , @b_Debug            = @b_Debug  
  
         IF @b_Success = 0   
         BEGIN  
            SET @n_Continue = 3  
            SET @n_Err = 82080  
            SET @c_ErrMsg = ISNULL(ERROR_MESSAGE(),'')  
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Error Executing ispSEPCDConsoLQ7.'  
                           + '(ispSEPCDB2B)' + ' (' + @c_ErrMsg + ')'  
            ROLLBACK TRAN   --WL01
            GOTO QUIT_SP  
         END  
         ELSE   --WL01 S
         BEGIN
            WHILE @@TRANCOUNT > 0
            BEGIN
               COMMIT TRAN
            END
         END
         --WL01 E
      END  

      FETCH NEXT FROM @CUR_WVSKU INTO  @c_Facility  
                                    ,  @c_Storerkey           
                                    ,  @c_Sku                 
                                    ,  @c_Lottable01                
                                    ,  @c_Lottable02             
                                    ,  @c_Lottable03          
                                    ,  @c_Lottable06          
                                    ,  @c_Lottable07          
                                    ,  @c_Lottable08          
                                    ,  @c_Lottable09          
                                    ,  @c_Lottable10          
                                    ,  @c_Lottable11          
                                    ,  @c_Lottable12          
                                    ,  @dt_Lottable13  
                                    ,  @n_QtyLeftToFullFill  
                                    ,  @n_MinShelfLife    
   END  
  
   CLOSE @CUR_WVSKU  
   DEALLOCATE @CUR_WVSKU    
  
QUIT_SP:  
   --WL01 S
   WHILE @@TRANCOUNT < @n_StartTCnt
      BEGIN TRAN
   --WL01 E

   IF @n_Continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SET @b_Success = 0  
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_StartTCnt  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
  
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispSEPCDB2B'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
   END  
   ELSE  
   BEGIN  
      SET @b_Success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END  
   END  
END -- procedure  

GO