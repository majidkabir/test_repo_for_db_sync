SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROCEDURE [WM].[lsp_TRFPopulateSOH_Wrapper_Test]  
   @c_TransferKey          NVARCHAR(10)
,  @b_Success              INT          = 1  OUTPUT   
,  @n_Err                  INT          = 0  OUTPUT
,  @c_Errmsg               NVARCHAR(255)= '' OUTPUT
,  @n_WarningNo            INT          = 0  OUTPUT
,  @c_ProceedWithWarning   CHAR(1)      = 'N' 
,  @c_UserName             NVARCHAR(128)= ''
,  @n_ErrGroupKey          INT          = 0  OUTPUT
AS  
BEGIN  
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue                 INT = 1
         , @n_StartTCnt                INT = @@TRANCOUNT

   DECLARE @c_TableName                NVARCHAR(50)   = 'TRANSFERDETAIL'
         , @c_SourceType               NVARCHAR(50)   = 'lsp_TRFPopulateSOH_Wrapper'
             
         , @c_Facility                 NVARCHAR(5)    = ''
         , @c_FromStorerkey            NVARCHAR(15)   = ''
         , @c_TransferLineNumber       NVARCHAR(20)   = ''
         , @c_TransferLineNumber_Last  NVARCHAR(20)   = ''
         , @c_FromSku                  NVARCHAR(20)   = ''
         , @c_FromPackkey              NVARCHAR(10)   = ''
         , @c_FromUOM                  NVARCHAR(10)   = ''
         , @c_Lot                      NVARCHAR(10)   = ''
         , @c_Loc                      NVARCHAR(10)   = ''
         , @c_ID                       NVARCHAR(10)   = ''
         , @c_Lottable01               NVARCHAR(18)   = ''         
         , @c_Lottable02               NVARCHAR(18)   = ''         
         , @c_Lottable03               NVARCHAR(18)   = ''         
         , @dt_Lottable04              DATETIME                  
         , @dt_Lottable05              DATETIME            
         , @c_Lottable06               NVARCHAR(30)   = ''         
         , @c_Lottable07               NVARCHAR(30)   = ''         
         , @c_Lottable08               NVARCHAR(30)   = ''         
         , @c_Lottable09               NVARCHAR(30)   = ''         
         , @c_Lottable10               NVARCHAR(30)   = ''         
         , @c_Lottable11               NVARCHAR(30)   = ''         
         , @c_Lottable12               NVARCHAR(30)   = ''         
         , @dt_Lottable13              DATETIME              
         , @dt_Lottable14              DATETIME          
         , @dt_Lottable15              DATETIME    
         , @c_ToLottable01             NVARCHAR(18)   = ''
         , @c_ToLottable02             NVARCHAR(18)   = ''
         , @c_ToLottable03             NVARCHAR(18)   = ''
         , @dt_ToLottable04            DATETIME           
         , @dt_ToLottable05            DATETIME           
         , @c_ToLottable06             NVARCHAR(30)   = ''
         , @c_ToLottable07             NVARCHAR(30)   = ''
         , @c_ToLottable08             NVARCHAR(30)   = ''
         , @c_ToLottable09             NVARCHAR(30)   = ''
         , @c_ToLottable10             NVARCHAR(30)   = ''
         , @c_ToLottable11             NVARCHAR(30)   = ''
         , @c_ToLottable12             NVARCHAR(30)   = ''
         , @dt_ToLottable13            DATETIME           
         , @dt_ToLottable14            DATETIME           
         , @dt_ToLottable15            DATETIME           
                                                          
         , @n_Qty                      INT            = 0
         , @n_FromQty                  INT            = 0
         , @n_OriginalQty              INT            = 0
         , @c_OriginalLineNo           NVARCHAR(5)    = ''
         , @c_NewLineNo                NVARCHAR(5)   = ''

         , @n_QtyAvailable             INT            = 0
         , @n_RemainQty                INT            = 0

         , @n_AttrCnt                  INT            = 1
         , @n_LineCnt                  INT            = 0
         , @b_NewLine                  BIT            = 0

         , @c_Code                     NVARCHAR(30)   = ''
         , @c_ListName                 NVARCHAR(10)   = ''
         , @c_SourceKey                NVARCHAR(15)   = ''
         , @c_LASourceType             NVARCHAR(20)   = 'TRANSFER'

         , @c_SQL                      NVARCHAR(4000) = ''
         , @c_SQLParms                 NVARCHAR(4000) = ''

         , @CUR_LOTCHK                 CURSOR
         , @CUR_PPLTRF                 CURSOR
         , @CUR_INV                    CURSOR

   SET @b_Success = 1
   SET @c_ErrMsg = ''

   SET @n_ErrGroupKey = 0

   SET @n_Err = 0 
   --(mingle01) - START   
   IF SUSER_SNAME() <> @c_UserName
   BEGIN
      EXEC [WM].[lsp_SetUser] 
            @c_UserName = @c_UserName  OUTPUT
         ,  @n_Err      = @n_Err       OUTPUT
         ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT
                
      IF @n_Err <> 0 
      BEGIN
         PRINT('error for username')
         GOTO EXIT_SP
      END
    
      EXECUTE AS LOGIN = @c_UserName
   END
   --(mingle01) - END
   
   PRINT('@n_WarningNo')
   PRINT(@n_WarningNo)
   --(mingle01) - START
   BEGIN TRY
      IF @c_ProceedWithWarning = 'N' AND @n_WarningNo  < 1
      BEGIN
         -------------------
         -- Validation Start
         -------------------
         PRINT('@c_ProceedWithWarning 1');
         SET @c_Facility = ''
         SELECT @c_Facility = T.Facility
         FROM [TRANSFER] T WITH (NOLOCK) 
         WHERE T.TransferKey = @c_TransferKey 
         
         PRINT('@c_Facility aaaa');
         PRINT(@c_Facility);
         IF @c_Facility = ''
         BEGIN
            PRINT('@c_Facility is empty');
            SET @n_continue = 3   
            SET @n_err = 554801
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) 
                          + ': Facility Cannot Be BLANK. (lsp_TRFPopulateSOH_Wrapper)'

            EXEC [WM].[lsp_WriteError_List] 
                  @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
               ,  @c_TableName   = @c_TableName
               ,  @c_SourceType  = @c_SourceType
               ,  @c_Refkey1     = @c_TransferKey
               ,  @c_Refkey2     = ''
               ,  @c_Refkey3     = ''
               ,  @c_WriteType   = 'ERROR'
               ,  @n_err2        = @n_err
               ,  @c_errmsg2     = @c_errmsg
               ,  @b_Success     = @b_Success   OUTPUT
               ,  @n_err         = @n_err       OUTPUT
               ,  @c_errmsg      = @c_errmsg    OUTPUT
         END
      END
      PRINT('@c_ErrMsg');
      PRINT(@c_ErrMsg);
      PRINT('@c_Facility here');
      PRINT(@c_Facility);
      -------------------
      -- Validation End
      -------------------

      -------------------
      -- Question Start
      -------------------

      IF @c_ProceedWithWarning = 'N' AND @n_WarningNo < 1
      BEGIN

         SET @c_ErrMsg = 'Do You Want To Continue Populate Candidate Stock Onhand?'
         PRINT('@c_ProceedWithWarning 2');
         EXEC [WM].[lsp_WriteError_List] 
               @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
            ,  @c_TableName   = @c_TableName
            ,  @c_SourceType  = @c_SourceType
            ,  @c_Refkey1     = @c_TransferKey
            ,  @c_Refkey2     = ''
            ,  @c_Refkey3     = ''
            ,  @c_WriteType   = 'QUESTION'
            ,  @n_err2        = @n_err
            ,  @c_errmsg2     = @c_errmsg
            ,  @b_Success     = @b_Success   OUTPUT
            ,  @n_err         = @n_err       OUTPUT
            ,  @c_errmsg      = @c_errmsg    OUTPUT

         IF EXISTS ( SELECT 1
                     FROM TRANSFERDETAIL TD WITH (NOLOCK)
                     WHERE TD.TransferKey = @c_TransferKey
                     AND  ( (ISNUMERIC(TD.UserDefine04) = 1 AND CONVERT(INT,TD.UserDefine04) > 0
                     OR      ISNULL(RTRIM(TD.UserDefine05),'') > '') ) 
                   )
         BEGIN    
            SET @c_ErrMsg = 'Do You Want To Reverse Existing Records to Original Records?'

            EXEC [WM].[lsp_WriteError_List] 
                  @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
               ,  @c_TableName   = @c_TableName
               ,  @c_SourceType  = @c_SourceType
               ,  @c_Refkey1     = @c_TransferKey
               ,  @c_Refkey2     = ''
               ,  @c_Refkey3     = ''
               ,  @c_WriteType   = 'QUESTION'
               ,  @n_err2        = @n_err
               ,  @c_errmsg2     = @c_errmsg
               ,  @b_Success     = @b_Success   OUTPUT
               ,  @n_err         = @n_err       OUTPUT
               ,  @c_errmsg      = @c_errmsg    OUTPUT
         END

         SET @n_WarningNo = 1

         GOTO EXIT_SP
      END

      PRINT('Warnings_1')
      PRINT(@n_WarningNo ) 
      PRINT('@c_ErrMsg_1')
      PRINT(@c_ErrMsg)
      -------------------
      -- Question END
      -------------------

      -------------------
      -- Populate STart
      -------------------

      SET @c_Facility = ''
      SELECT @c_Facility = T.Facility
      FROM [TRANSFER]  T WITH (NOLOCK) 
      WHERE T.TransferKey = @c_TransferKey 
      PRINT('@c_Facility here1');
      PRINT(@c_Facility);
      SET @c_TransferLineNumber = ''
      WHILE 1=1
      BEGIN
         SELECT TOP 1
                @c_TransferLineNumber = TD.TransferLineNumber 
               ,@c_FromSku = RTRIM(TD.FromSku)
               ,@n_OriginalQty = CASE WHEN ISNUMERIC(TD.UserDefine04) = 1 THEN CONVERT(INT,TD.UserDefine04) ELSE 0 END
               ,@c_OriginalLineNo= ISNULL(RTRIM(TD.UserDefine05),'')
         FROM TRANSFERDETAIL TD WITH (NOLOCK)
         WHERE TD.TransferKey = @c_TransferKey
         AND TD.TransferLineNumber > @c_TransferLineNumber
         ORDER BY TD.TransferLineNumber
            PRINT('@c_TransferLineNumber');
            PRINT(@c_TransferLineNumber);
            PRINT('@c_FromSku');
            PRINT(@c_FromSku);
            PRINT('@n_OriginalQty');
            PRINT(@n_OriginalQty);
            PRINT('@c_OriginalLineNo');
            PRINT(@c_OriginalLineNo);
         IF @@ROWCOUNT = 0 
         BEGIN
            BREAK
         END

         IF @c_OriginalLineNo > '' OR @c_FromSku = ''
         BEGIN
            BEGIN TRY
                PRINT(' DELETE FROM TRANSFERDETAI');
               DELETE FROM TRANSFERDETAIL
               WHERE TransferKey = @c_TransferKey
               AND TransferLineNumber = @c_TransferLineNumber
            END TRY

            BEGIN CATCH
               SET @n_continue = 3
               SET @n_err = 554801
               SET @c_ErrMsg   = ERROR_MESSAGE() 
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) 
                              + ': Delete TRANSFERDETAIL Table fail. (lsp_TRFPopulateSOH_Wrapper)'
                              + ' (' + @c_ErrMsg + ')'
               GOTO EXIT_SP
            END CATCH
         END

         IF @n_OriginalQty > ''
         BEGIN
            BEGIN TRY
                PRINT(' UPDATE FROM TRANSFERDETAI');
               UPDATE TRANSFERDETAIL
                  SET FromQty = @n_OriginalQty
                     ,ToQty   = @n_OriginalQty
                     ,Toloc   = 'PRStage'
                     ,ToLot   = ''
                     ,UserDefine04 = ''
                     ,UserDefine05 = ''
                     ,EditWho = @c_UserName
                     ,EditDate= GETDATE()
               WHERE TransferKey = @c_TransferKey
               AND TransferLineNumber = @c_TransferLineNumber
            END TRY

            BEGIN CATCH
               SET @n_continue = 3
               SET @n_err = 554803
               SET @c_ErrMsg   = ERROR_MESSAGE() 
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) 
                              + ': UPDATE TRANSFERDETAIL Table fail. (lsp_TRFPopulateSOH_Wrapper)'
                              + ' (' + @c_ErrMsg + ')'
               GOTO EXIT_SP
            END CATCH
         END
      END

      SET @c_SQL = N'SET @CUR_INV = CURSOR FAST_FORWARD READ_ONLY FOR'                                 
                 + '  SELECT'                                                                                 
                 + '   Lot = LLI.Lot'                                                                        
                 + ',  Loc = LLI.Loc'                                                                        
                 + ',  ID = LLI.ID'                                                                          
                 + ',  QtyAvailable = LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked'                            
                 + ',  Lottable01   = Lottable01'                                                            
                 + ',  Lottable02   = Lottable02'                                                            
                 + ',  Lottable03   = Lottable03'                                                            
                 + ',  Lottable04   = Lottable04'                                                            
                 + ',  Lottable05   = Lottable05'                                                            
                 + ',  Lottable06   = Lottable06'                                                            
                 + ',  Lottable07   = Lottable07'                                                            
                 + ',  Lottable08   = Lottable08'                                                            
                 + ',  Lottable09   = Lottable09'                                                            
                 + ',  Lottable10   = Lottable10'                                                            
                 + ',  Lottable11   = Lottable11'                                                            
                 + ',  Lottable12   = Lottable12'                                                            
                 + ',  Lottable13   = Lottable13'                                                            
                 + ',  Lottable14   = Lottable14'                                                            
                 + ',  Lottable15   = Lottable15'                                                            
                 + ' FROM LOTxLOCxID LLI WITH (NOLOCK)'                                                      
                 + ' JOIN LOT LOT WITH (NOLOCK) ON (LLI.Lot = LOT.Lot)'                               
                 + ' JOIN LOC L   WITH (NOLOCK) ON (LLI.Loc = L.Loc AND L.Facility = @c_Facility)'    
                 + ' JOIN ID  ID  WITH (NOLOCK) ON (LLI.ID = ID.ID)'                                  
                 + ' JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (LLI.Lot = LA.Lot)'                               
                 + ' WHERE LLI.Storerkey = @c_FromStorerkey'                                                 
                 + ' AND   LLI.Sku = @c_FromSku'                                                             
                 + ' AND   LLI.Qty > LLI.QtyAllocated + LLI.QtyPicked'                                       
      
      SET @CUR_LOTCHK = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT  Code
      FROM   CODELKUP WITH (NOLOCK)
      WHERE  Listname = 'TRNCHKLOTR'

      OPEN @CUR_LOTCHK
      FETCH NEXT FROM @CUR_LOTCHK INTO @c_Code

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF @c_Code = 'LOTTABLE01'
         BEGIN
            SET @c_SQL = @c_SQL + N' AND LA.Lottable01 = @c_Lottable01'
         END
         IF @c_Code = 'LOTTABLE02'
         BEGIN
            SET @c_SQL = @c_SQL + N' AND LA.Lottable02 = @c_Lottable02'
         END
         IF @c_Code = 'LOTTABLE03'
         BEGIN
            SET @c_SQL = @c_SQL + N' AND LA.Lottable03 = @c_Lottable03'
         END
         IF @c_Code = 'LOTTABLE04'
         BEGIN
            SET @c_SQL = @c_SQL + N' AND LA.Lottable04 = @dt_Lottable04'
         END
         IF @c_Code = 'LOTTABLE05'
         BEGIN
            SET @c_SQL = @c_SQL + N' AND LA.Lottable05 = @dt_Lottable05'
         END
         IF @c_Code = 'LOTTABLE06'
         BEGIN
            SET @c_SQL = @c_SQL + N' AND LA.Lottable06 = @c_Lottable06'
         END
         IF @c_Code = 'LOTTABLE07'
         BEGIN
            SET @c_SQL = @c_SQL + N' AND LA.Lottable07 = @c_Lottable07'
         END
         IF @c_Code = 'LOTTABLE08'
         BEGIN
            SET @c_SQL = @c_SQL + N' AND LA.Lottable08 = @c_Lottable08'
         END
         IF @c_Code = 'LOTTABLE09'
         BEGIN
            SET @c_SQL = @c_SQL + N' AND LA.Lottable09 = @c_Lottable09'
         END
         IF @c_Code = 'LOTTABLE10'
         BEGIN
            SET @c_SQL = @c_SQL + N' AND LA.Lottable10 = @c_Lottable10'
         END
         IF @c_Code = 'LOTTABLE11'
         BEGIN
            SET @c_SQL = @c_SQL + N' AND LA.Lottable11 = @c_Lottable11'
         END
         IF @c_Code = 'LOTTABLE12'
         BEGIN
            SET @c_SQL = @c_SQL + N' AND LA.Lottable12 = @c_Lottable12'
         END
         IF @c_Code = 'LOTTABLE13'
         BEGIN
            SET @c_SQL = @c_SQL + N' AND LA.Lottable13 = @dt_Lottable13'
         END
         IF @c_Code = 'LOTTABLE14'
         BEGIN
            SET @c_SQL = @c_SQL + N' AND LA.Lottable14 = @dt_Lottable14'
         END
         IF @c_Code = 'LOTTABLE15'
         BEGIN
            SET @c_SQL = @c_SQL + N' AND LA.Lottable15 = @dt_Lottable15'
         END
         FETCH NEXT FROM @CUR_LOTCHK INTO @c_Code
      END
      CLOSE @CUR_LOTCHK
      DEALLOCATE @CUR_LOTCHK

      SET @c_SQL = @c_SQL 
                 + N' ORDER BY LA.Lottable04'                                                                 
                 +         ', LA.Lottable05; OPEN @CUR_INV; '     
      SET @c_SQLParms = N'@c_FromStorerkey   NVARCHAR(15)'          
                      + ',@c_FromSku         NVARCHAR(20)'          
                      + ',@c_Facility        NVARCHAR(5)'           
                      + ',@c_Lottable01      NVARCHAR(18)'          
                      + ',@c_Lottable02      NVARCHAR(18)'          
                      + ',@c_Lottable03      NVARCHAR(18)'          
                      + ',@dt_Lottable04     DATETIME'              
                      + ',@dt_Lottable05     DATETIME'              
                      + ',@c_Lottable06      NVARCHAR(30)'          
                      + ',@c_Lottable07      NVARCHAR(30)'          
                      + ',@c_Lottable08      NVARCHAR(30)'          
                      + ',@c_Lottable09      NVARCHAR(30)'          
                      + ',@c_Lottable10      NVARCHAR(30)'          
                      + ',@c_Lottable11      NVARCHAR(30)'          
                      + ',@c_Lottable12      NVARCHAR(30)'          
                      + ',@dt_Lottable13     DATETIME'              
                      + ',@dt_Lottable14     DATETIME'              
                      + ',@dt_Lottable15     DATETIME'   
                      + ',@CUR_INV           CURSOR OUTPUT'           
    PRINT('@c_SQL')
    PRINT(@c_SQL)
    PRINT('@c_SQLParms')
    PRINT(@c_SQLParms)
    --   SELECT TOP 1 @c_TransferLineNumber_Last = TD.TransferLineNumber
    --   FROM TRANSFERDETAIL TD WITH (NOLOCK)
    --   WHERE TD.TransferKey = @c_TransferKey
    --   ORDER BY TD.TransferLineNumber DESC

    --   SET @n_LineCnt = CONVERT(INT,@c_TransferLineNumber_Last) 

    --   SET @CUR_PPLTRF = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
    --   SELECT   TD.TransferLineNumber
    --         ,  TD.FromStorerkey  
    --         ,  FromSku = RTRIM(TD.FromSku)
    --         ,  FromQty = RTRIM(TD.FromQty)
    --         ,  Lottable01   = Lottable01  
    --         ,  Lottable02   = Lottable02  
    --         ,  Lottable03   = Lottable03  
    --         ,  Lottable04   = Lottable04  
    --         ,  Lottable05   = Lottable05  
    --         ,  Lottable06   = Lottable06  
    --         ,  Lottable07   = Lottable07  
    --         ,  Lottable08   = Lottable08  
    --         ,  Lottable09   = Lottable09  
    --         ,  Lottable10   = Lottable10  
    --         ,  Lottable11   = Lottable11  
    --         ,  Lottable12   = Lottable12 
    --         ,  Lottable13   = Lottable13  
    --         ,  Lottable14   = Lottable14 
    --         ,  Lottable15   = Lottable15
    --   FROM TRANSFERDETAIL TD WITH (NOLOCK)
    --   WHERE TD.TransferKey = @c_TransferKey
    --   AND   TD.FromQty     > 0
    --   ORDER BY TD.TransferLineNumber

    --   OPEN @CUR_PPLTRF
    --   FETCH NEXT FROM @CUR_PPLTRF INTO @c_TransferLineNumber
    --                                 ,  @c_FromStorerkey
    --                                 ,  @c_FromSku 
    --                                 ,  @n_FromQty
    --                                 ,  @c_Lottable01      
    --                                 ,  @c_Lottable02    
    --                                 ,  @c_Lottable03    
    --                                 ,  @dt_Lottable04   
    --                                 ,  @dt_Lottable05  
    --                                 ,  @c_Lottable06    
    --                                 ,  @c_Lottable07    
    --                                 ,  @c_Lottable08     
    --                                 ,  @c_Lottable09      
    --                                 ,  @c_Lottable10     
    --                                 ,  @c_Lottable11   
    --                                 ,  @c_Lottable12    
    --                                 ,  @dt_Lottable13  
    --                                 ,  @dt_Lottable14   
    --                                 ,  @dt_Lottable15 

    --   WHILE @@FETCH_STATUS <> -1
    --   BEGIN
    --      IF @c_TransferLineNumber_Last < @c_TransferLineNumber
    --      BEGIN 
    --         GOTO NEXT_TRFREC 
    --      END

    --      SET @b_NewLine     = 0
    --      SET @n_OriginalQty = @n_FromQty
    --      SET @n_RemainQty   = @n_FromQty
    --      SET @c_OriginalLineNo = @c_TransferLineNumber

    --      EXEC sp_ExecuteSQL @c_SQL 
    --                        ,@c_SQLParms
    --                        ,@c_FromStorerkey
    --                        ,@c_FromSku
    --                        ,@c_Facility
    --                        ,@c_Lottable01      
    --                        ,@c_Lottable02    
    --                        ,@c_Lottable03    
    --                        ,@dt_Lottable04   
    --                        ,@dt_Lottable05  
    --                        ,@c_Lottable06    
    --                        ,@c_Lottable07    
    --                        ,@c_Lottable08     
    --                        ,@c_Lottable09      
    --                        ,@c_Lottable10     
    --                        ,@c_Lottable11   
    --                        ,@c_Lottable12    
    --                        ,@dt_Lottable13  
    --                        ,@dt_Lottable14   
    --                        ,@dt_Lottable15 
    --                        ,@CUR_INV         OUTPUT

    --       FETCH NEXT FROM @CUR_INV INTO @c_Lot 
    --                                 ,  @c_Loc 
    --                                 ,  @c_ID  
    --                                 ,  @n_QtyAvailable 
    --                                 ,  @c_Lottable01      
    --                                 ,  @c_Lottable02    
    --                                 ,  @c_Lottable03    
    --                                 ,  @dt_Lottable04   
    --                                 ,  @dt_Lottable05  
    --                                 ,  @c_Lottable06    
    --                                 ,  @c_Lottable07    
    --                                 ,  @c_Lottable08     
    --                                 ,  @c_Lottable09      
    --                                 ,  @c_Lottable10     
    --                                 ,  @c_Lottable11   
    --                                 ,  @c_Lottable12    
    --                                 ,  @dt_Lottable13  
    --                                 ,  @dt_Lottable14   
    --                                 ,  @dt_Lottable15 
      
    --      WHILE @@FETCH_STATUS <> -1 AND @n_RemainQty > 0
    --      BEGIN
    --         SET @c_ToLottable01  = @c_Lottable01          
    --         SET @c_ToLottable02  = @c_Lottable02          
    --         SET @c_ToLottable03  = @c_Lottable03          
    --         SET @dt_ToLottable04 = @dt_Lottable04         
    --         SET @dt_ToLottable05 = @dt_Lottable05         
    --         SET @c_ToLottable06  = @c_Lottable06          
    --         SET @c_ToLottable07  = @c_Lottable07          
    --         SET @c_ToLottable08  = @c_Lottable08          
    --         SET @c_ToLottable09  = @c_Lottable09          
    --         SET @c_ToLottable10  = @c_Lottable10          
    --         SET @c_ToLottable11  = @c_Lottable11          
    --         SET @c_ToLottable12  = @c_Lottable12          
    --         SET @dt_ToLottable13 = @dt_Lottable13         
    --         SET @dt_ToLottable14 = @dt_Lottable14         
    --         SET @dt_ToLottable15 = @dt_Lottable15         

    --         SET @c_Sourcekey = @c_Transferkey + @c_OriginalLineNo
    --         SET @n_AttrCnt = 1
    --         WHILE @n_AttrCnt <= 10
    --         BEGIN
    --            SET @c_ListName = CASE WHEN @n_AttrCnt = 1  THEN 'LOTTABLE01'
    --                                   WHEN @n_AttrCnt = 2  THEN 'LOTTABLE02'
    --                                   WHEN @n_AttrCnt = 3  THEN 'LOTTABLE03'
    --                                   WHEN @n_AttrCnt = 4  THEN 'LOTTABLE04'
    --                                   WHEN @n_AttrCnt = 5  THEN 'LOTTABLE05'
    --                                   WHEN @n_AttrCnt = 6  THEN 'LOTTABLE06'  
    --                                   WHEN @n_AttrCnt = 7  THEN 'LOTTABLE07'  
    --                                   WHEN @n_AttrCnt = 8  THEN 'LOTTABLE08'  
    --                                   WHEN @n_AttrCnt = 9  THEN 'LOTTABLE09'  
    --                                   WHEN @n_AttrCnt = 10 THEN 'LOTTABLE10'  
    --                                   WHEN @n_AttrCnt = 11 THEN 'LOTTABLE11'   
    --                                   WHEN @n_AttrCnt = 12 THEN 'LOTTABLE12'   
    --                                   WHEN @n_AttrCnt = 13 THEN 'LOTTABLE13'   
    --                                   WHEN @n_AttrCnt = 14 THEN 'LOTTABLE14'   
    --                                   WHEN @n_AttrCnt = 15 THEN 'LOTTABLE15' 
    --                                   END  
    --            BEGIN TRY
    --               SET @b_Success = 1
    --               EXEC ispLottableRule_Wrapper                             
    --                                   @c_SPName           = ''                         
    --                                 , @c_Listname         = @c_Listname                  
    --                                 , @c_Storerkey        = @c_FromStorerkey             
    --                                 , @c_Sku              = @c_FromSku                   
    --                                 , @c_LottableLabel    = ''                           
    --                                 , @c_Lottable01Value  = ''                           
    --                                 , @c_Lottable02Value  = ''                           
    --                                 , @c_Lottable03Value  = ''                           
    --                                 , @dt_Lottable04Value = ''                           
    --                                 , @dt_Lottable05Value = ''                           
    --                                 , @c_Lottable06Value  = ''                           
    --                                 , @c_Lottable07Value  = ''                           
    --                                 , @c_Lottable08Value  = ''                           
    --                                 , @c_Lottable09Value  = ''                           
    --                                 , @c_Lottable10Value  = ''                           
    --                                 , @c_Lottable11Value  = ''                           
    --                                 , @c_Lottable12Value  = ''                           
    --                                 , @dt_Lottable13Value = ''                           
    --                                 , @dt_Lottable14Value = ''                           
    --                                 , @dt_Lottable15Value = ''                           
    --                                 , @c_Lottable01       = @c_ToLottable01       OUTPUT 
    --                                 , @c_Lottable02       = @c_ToLottable02       OUTPUT 
    --                                 , @c_Lottable03       = @c_ToLottable03       OUTPUT 
    --                                 , @dt_Lottable04      = @dt_ToLottable04      OUTPUT 
    --                                 , @dt_Lottable05      = @dt_ToLottable05      OUTPUT 
    --                                 , @c_Lottable06       = @c_ToLottable06       OUTPUT 
    --                                 , @c_Lottable07       = @c_ToLottable07       OUTPUT 
    --                                 , @c_Lottable08       = @c_ToLottable08       OUTPUT 
    --                                 , @c_Lottable09       = @c_ToLottable09       OUTPUT 
    --                                 , @c_Lottable10       = @c_ToLottable10       OUTPUT 
    --                                 , @c_Lottable11       = @c_ToLottable11       OUTPUT 
    --                                 , @c_Lottable12       = @c_ToLottable12       OUTPUT 
    --                                 , @dt_Lottable13      = @dt_ToLottable13      OUTPUT 
    --                                 , @dt_Lottable14      = @dt_ToLottable14      OUTPUT 
    --                                 , @dt_Lottable15      = @dt_ToLottable15      OUTPUT 
    --                                 , @b_Success          = @b_Success            OUTPUT 
    --                                 , @n_Err              = @n_Err                OUTPUT 
    --                                 , @c_Errmsg           = @c_Errmsg             OUTPUT 
    --                                 , @c_Sourcekey        = @c_Sourcekey                 
    --                                 , @c_Sourcetype       = @c_LASourceType  
    --            END TRY
    --            BEGIN CATCH
    --               SET @n_err = 554804
    --               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) 
    --                              + ': Error Executing ispLottableRule_Wrapper. (lsp_TRFPopulateSOH_Wrapper)'
    --                              + ' (' + @c_ErrMsg + ')'
    --            END CATCH
               
    --            IF @b_Success = 0 OR @n_Err <> 0
    --            BEGIN
    --               SET @n_Continue = 3
    --               GOTO EXIT_SP
    --            END 
    --            SET @n_AttrCnt = @n_AttrCnt + 1                  
    --         END

    --         IF @n_RemainQty < @n_QtyAvailable
    --         BEGIN
    --            SET @n_Qty = @n_RemainQty
    --         END
    --         ELSE
    --         BEGIN
    --            SET @n_Qty = @n_QtyAvailable
    --         END

    --         SET @n_RemainQty = @n_RemainQty - @n_Qty

    --         IF @n_Qty > 0
    --         BEGIN
    --            IF @b_NewLine = 0 
    --            BEGIN
    --               SET @b_NewLine = 1
    --               BEGIN TRY
    --                  UPDATE TRANSFERDETAIL
    --                     SET   FromLot = @c_Lot
    --                        ,  FromLoc = @c_Loc
    --                        ,  FromID  = @c_ID
    --                        ,  FromQty = @n_Qty
    --                        ,  Lottable01 = @c_Lottable01    
    --                        ,  Lottable02 = @c_Lottable02    
    --                        ,  Lottable03 = @c_Lottable03    
    --                        ,  Lottable04 = @dt_Lottable04   
    --                        ,  Lottable05 = @dt_Lottable05   
    --                        ,  Lottable06 = @c_Lottable06    
    --                        ,  Lottable07 = @c_Lottable07    
    --                        ,  Lottable08 = @c_Lottable08    
    --                        ,  Lottable09 = @c_Lottable09    
    --                        ,  Lottable10 = @c_Lottable10    
    --                        ,  Lottable11 = @c_Lottable11    
    --                        ,  Lottable12 = @c_Lottable12    
    --                        ,  Lottable13 = @dt_Lottable13   
    --                        ,  Lottable14 = @dt_Lottable14   
    --                        ,  Lottable15 = @dt_Lottable15  
    --                        ,  ToStorerkey= @c_FromStorerkey            
    --                        ,  ToSku      = @c_FromSku                  
    --                        ,  ToPackkey  = @c_FromPackkey              
    --                        ,  ToUOM      = @c_FromUOM                  
    --                        ,  ToLot   = ''
    --                        ,  ToLoc   = @c_Loc
    --                        ,  ToID    = @c_ID
    --                        ,  ToQty   = @n_Qty                                            
    --                        ,  ToLottable01   = @c_ToLottable01  
    --                        ,  ToLottable02   = @c_ToLottable02  
    --                        ,  ToLottable03   = @c_ToLottable03  
    --                        ,  ToLottable04   = @dt_ToLottable04 
    --                        ,  ToLottable05   = @dt_ToLottable05 
    --                        ,  ToLottable06   = @c_ToLottable06  
    --                        ,  ToLottable07   = @c_ToLottable07  
    --                        ,  ToLottable08   = @c_ToLottable08  
    --                        ,  ToLottable09   = @c_ToLottable09  
    --                        ,  ToLottable10   = @c_ToLottable10  
    --                        ,  ToLottable11   = @c_ToLottable11  
    --                        ,  ToLottable12   = @c_ToLottable12  
    --                        ,  ToLottable13   = @dt_ToLottable13 
    --                        ,  ToLottable14   = @dt_ToLottable14 
    --                        ,  ToLottable15   = @dt_ToLottable15 
    --                        ,  UserDefine04   = @n_OriginalQty
    --                        ,  EditWho  = SUSER_NAME()
    --                        ,  EditDate = GETDATE()
    --                  WHERE TransferKey = @c_TransferKey
    --                  AND TransferLineNumber = @c_TransferLineNumber
    --               END TRY

    --               BEGIN CATCH
    --                  SET @n_continue = 3
    --                  SET @n_err = 554805
    --                  SET @c_ErrMsg   = ERROR_MESSAGE() 
    --                  SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) 
    --                                 + ': Update TRANSFERDETAIL Table fail. (lsp_TRFPopulateSOH_Wrapper)'
    --                                 + ' (' + @c_ErrMsg + ')'
    --                  GOTO EXIT_SP
    --               END CATCH
    --            END
    --            ELSE
    --            BEGIN
    --               SET @n_LineCnt = @n_LineCnt + 1
    --               SET @c_NewLineNo = RIGHT('00000' + CONVERT(NVARCHAR(5), @n_LineCnt),5)
    --               BEGIN TRY
    --                  INSERT INTO TRANSFERDETAIL
    --                     (  TransferKey
    --                     ,  TransferLineNumber
    --                     ,  FromStorerkey
    --                     ,  FromSku
    --                     ,  FromPackkey
    --                     ,  FromUOM
    --                     ,  FromLot
    --                     ,  FromLoc
    --                     ,  FromID
    --                     ,  FromQty
    --                     ,  Lottable01     
    --                     ,  Lottable02     
    --                     ,  Lottable03     
    --                     ,  Lottable04     
    --                     ,  Lottable05     
    --                     ,  Lottable06     
    --                     ,  Lottable07     
    --                     ,  Lottable08     
    --                     ,  Lottable09     
    --                     ,  Lottable10     
    --                     ,  Lottable11     
    --                     ,  Lottable12     
    --                     ,  Lottable13     
    --                     ,  Lottable14     
    --                     ,  Lottable15  
    --                     ,  ToStorerkey
    --                     ,  ToSku
    --                     ,  ToPackkey
    --                     ,  ToUOM
    --                     ,  ToLot
    --                     ,  ToLoc
    --                     ,  ToID
    --                     ,  ToQty
    --                     ,  ToLottable01     
    --                     ,  ToLottable02     
    --                     ,  ToLottable03     
    --                     ,  ToLottable04     
    --                     ,  ToLottable05     
    --                     ,  ToLottable06     
    --                     ,  ToLottable07     
    --                     ,  ToLottable08     
    --                     ,  ToLottable09     
    --                     ,  ToLottable10     
    --                     ,  ToLottable11     
    --                     ,  ToLottable12     
    --                     ,  ToLottable13     
    --                     ,  ToLottable14     
    --                     ,  ToLottable15 
    --                     ,  UserDefine01
    --                     ,  UserDefine02
    --                     ,  UserDefine03
    --                     ,  UserDefine04
    --                     ,  UserDefine05
    --                     ,  UserDefine06
    --                     ,  UserDefine07
    --                     ,  UserDefine08
    --                     ,  UserDefine09
    --                     ,  UserDefine10
    --                     )
    --                  SELECT
    --                        @c_TransferKey
    --                     ,  @c_NewLineNo
    --                     ,  @c_FromStorerkey
    --                     ,  @c_FromSku
    --                     ,  TD.FromPackkey
    --                     ,  TD.FromUOM
    --                     ,  @c_Lot
    --                     ,  @c_Loc
    --                     ,  @c_ID
    --                     ,  @n_Qty
    --                     ,  @c_Lottable01     
    --                     ,  @c_Lottable02     
    --                     ,  @c_Lottable03     
    --                     ,  @dt_Lottable04     
    --                     ,  @dt_Lottable05     
    --                     ,  @c_Lottable06     
    --                     ,  @c_Lottable07     
    --                     ,  @c_Lottable08     
    --                     ,  @c_Lottable09     
    --                     ,  @c_Lottable10     
    --                     ,  @c_Lottable11     
    --                     ,  @c_Lottable12     
    --                     ,  @dt_Lottable13     
    --                     ,  @dt_Lottable14     
    --                     ,  @dt_Lottable15 
    --                     ,  @c_FromStorerkey
    --                     ,  @c_FromSku
    --                     ,  TD.FromPackkey
    --                     ,  TD.FromUOM
    --                     ,  ''
    --                     ,  @c_Loc
    --                     ,  @c_ID
    --                     ,  @n_Qty
    --                     ,  @c_ToLottable01       
    --                     ,  @c_ToLottable02       
    --                     ,  @c_ToLottable03       
    --                     ,  @dt_ToLottable04      
    --                     ,  @dt_ToLottable05      
    --                     ,  @c_ToLottable06       
    --                     ,  @c_ToLottable07       
    --                     ,  @c_ToLottable08       
    --                     ,  @c_ToLottable09       
    --                     ,  @c_ToLottable10       
    --                     ,  @c_ToLottable11       
    --                     ,  @c_ToLottable12       
    --                     ,  @dt_ToLottable13      
    --                     ,  @dt_ToLottable14      
    --                     ,  @dt_ToLottable15      
    --                     ,  TD.UserDefine01
    --                     ,  TD.UserDefine02
    --                     ,  TD.UserDefine03
    --                     ,  @n_OriginalQty
    --                     ,  @c_OriginalLineNo
    --                     ,  TD.UserDefine06
    --                     ,  TD.UserDefine07
    --                     ,  TD.UserDefine08
    --                     ,  TD.UserDefine09
    --                     ,  TD.UserDefine10
    --                  FROM TRANSFERDETAIL TD WITH (NOLOCK)
    --                  WHERE TD.TransferKey = @c_TransferKey
    --                  AND TD.TransferLineNumber = @c_OriginalLineNo
    --               END TRY

    --               BEGIN CATCH
    --                  SET @n_continue = 3
    --                  SET @n_err = 554806
    --                  SET @c_ErrMsg   = ERROR_MESSAGE()    
    --                  SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) 
    --                                 + ': Insert TRANSFERDETAIL Fail. (lsp_TRFPopulateSOH_Wrapper)'
    --                                 + ' (' + @c_ErrMsg + ')'
    --                  GOTO EXIT_SP
    --               END CATCH
    --            END
    --         END

    --         FETCH NEXT FROM @CUR_INV INTO @c_Lot 
    --                                    ,  @c_Loc 
    --                                    ,  @c_ID  
    --                                    ,  @n_QtyAvailable 
    --                                    ,  @c_Lottable01      
    --                                    ,  @c_Lottable02    
    --                                    ,  @c_Lottable03    
    --                                    ,  @dt_Lottable04   
    --                                    ,  @dt_Lottable05  
    --                                    ,  @c_Lottable06    
    --                                    ,  @c_Lottable07    
    --                                    ,  @c_Lottable08     
    --                                    ,  @c_Lottable09      
    --                                    ,  @c_Lottable10     
    --                                    ,  @c_Lottable11   
    --                                    ,  @c_Lottable12    
    --                                    ,  @dt_Lottable13  
    --                                    ,  @dt_Lottable14   
    --                                    ,  @dt_Lottable15 
    --      END
    --      CLOSE @CUR_INV
    --      DEALLOCATE @CUR_INV

    --      IF @b_NewLine > 1 AND @n_RemainQty > 0 
    --      BEGIN
    --         SET @n_continue = 3
    --         SET @n_err = 554807
    --         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) 
    --                        + ': Qty populated does not match Original Qty ! Transfer line number is ' + RTRIM(@c_TransferLineNumber)
    --                        + ', OriginalQty is ' + CONVERT(NVARCHAR(5), @n_OriginalQty) + ', Populated Qty is ' + CONVERT(NVARCHAR(5), @n_OriginalQty - @n_RemainQty)
    --                        + '. (lsp_TRFPopulateSOH_Wrapper)'
    --                        + ' |' + RTRIM(@c_TransferLineNumber) + '|' + CONVERT(NVARCHAR(5), @n_OriginalQty)
    --                        + '|'  + CONVERT(NVARCHAR(5), @n_OriginalQty - @n_RemainQty)

    --         EXEC [WM].[lsp_WriteError_List] 
    --               @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
    --            ,  @c_TableName   = @c_TableName
    --            ,  @c_SourceType  = @c_SourceType
    --            ,  @c_Refkey1     = @c_TransferKey
    --            ,  @c_Refkey2     = @c_TransferLineNumber
    --            ,  @c_Refkey3     = ''
    --            ,  @n_err2        = @n_err
    --            ,  @c_errmsg2     = @c_errmsg
    --            ,  @b_Success     = @b_Success   OUTPUT
    --            ,  @n_err         = @n_err       OUTPUT
    --            ,  @c_errmsg      = @c_errmsg    OUTPUT
    --      END

    --      NEXT_TRFREC:
    --      FETCH NEXT FROM @CUR_PPLTRF INTO @c_TransferLineNumber
    --                                    ,  @c_FromStorerkey
    --                                    ,  @c_FromSku 
    --                                    ,  @n_FromQty
    --                                    ,  @c_Lottable01      
    --                                    ,  @c_Lottable02    
    --                                    ,  @c_Lottable03    
    --                                    ,  @dt_Lottable04   
    --                                    ,  @dt_Lottable05  
    --                                    ,  @c_Lottable06    
    --                                    ,  @c_Lottable07    
    --                                    ,  @c_Lottable08     
    --                                    ,  @c_Lottable09      
    --                                    ,  @c_Lottable10     
    --                                    ,  @c_Lottable11   
    --                                    ,  @c_Lottable12    
    --                                    ,  @dt_Lottable13  
    --                                    ,  @dt_Lottable14   
    --                                    ,  @dt_Lottable15 
                                       
     
    --   END
    --   CLOSE @CUR_PPLTRF
    --   DEALLOCATE @CUR_PPLTRF 
   END TRY
   
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH
   --(mingle01) - END 
   -------------------
   -- Explode End
   -------------------
   EXIT_SP:
   
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

      SET @n_WarningNo = 0
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_TRFPopulateSOH_Wrapper'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END

   REVERT      
END  

GO