SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: lsp_TRF_PopulateSN_Wrapper                          */                                                                                  
/* Creation Date: 2024-07-16                                            */                                                                                  
/* Copyright: Maersk Logistics                                          */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: LFWM-4446 - RG [GIT] Serial Number Solution                 */
/*          - Transfer by Serial Number                                 */
/*                                                                      */
/* Called By: SCE                                                       */                                                                                  
/*          :                                                           */                                                                                  
/*                                                                      */                                                                                  
/* Version: V0                                                          */                                                                                  
/*                                                                      */                                                                                  
/* Data Modifications:                                                  */                                                                                  
/*                                                                      */                                                                                  
/* Updates:                                                             */                                                                                  
/* Date        Author   Ver.  Purposes                                  */
/************************************************************************/                                                                                  
CREATE   PROC [WM].[lsp_TRF_PopulateSN_Wrapper]                                                                                                                     
   @c_TransferKey          NVARCHAR(10)         
,  @c_SearchSQL            NVARCHAR(MAX)              --Select Statement (Get SerialNo FROM SerialNo Table) for Populate Search button
,  @b_Success              INT = 1           OUTPUT  
,  @n_err                  INT = 0           OUTPUT                                                                                                             
,  @c_ErrMsg               NVARCHAR(255)= '' OUTPUT
,  @n_ErrGroupKey          INT          = 0  OUTPUT    
,  @c_UserName             NVARCHAR(128)= ''  
AS  
BEGIN                                                                                                                                                        
   SET NOCOUNT ON                                                                                                                                           
   SET ANSI_NULLS OFF                                                                                                                                       
   SET QUOTED_IDENTIFIER OFF                                                                                                                                
   SET CONCAT_NULL_YIELDS_NULL OFF       

   DECLARE  @n_StartTCnt                  INT = @@TRANCOUNT  
         ,  @n_Continue                   INT = 1

         ,  @c_SelectSQL                  NVARCHAR(4000)

         ,  @c_FromFacility               NVARCHAR(5)    = ''
         ,  @c_FromStorerkey              NVARCHAR(15)   = ''
         ,  @c_ToFacility                 NVARCHAR(5)    = ''
         ,  @c_ToStorerkey                NVARCHAR(15)   = '' 
         ,  @c_TransferLineNumber         NVARCHAR(5)    = ''
         ,  @c_FromSku                    NVARCHAR(20)   = ''
         ,  @c_FromPackkey                NVARCHAR(10)   = ''
         ,  @c_FromUOM                    NVARCHAR(10)   = ''
         ,  @c_FromLot                    NVARCHAR(10)   = ''
         ,  @c_FromLoc                    NVARCHAR(10)   = ''
         ,  @c_FromID                     NVARCHAR(18)   = ''
         ,  @c_FromLottable01             NVARCHAR(18)   = ''
         ,  @c_FromLottable02             NVARCHAR(18)   = ''
         ,  @c_FromLottable03             NVARCHAR(18)   = ''
         ,  @dt_FromLottable04            DATETIME       = NULL
         ,  @dt_FromLottable05            DATETIME       = NULL
         ,  @c_FromLottable06             NVARCHAR(30)   = ''
         ,  @c_FromLottable07             NVARCHAR(30)   = ''
         ,  @c_FromLottable08             NVARCHAR(30)   = ''
         ,  @c_FromLottable09             NVARCHAR(30)   = ''
         ,  @c_FromLottable10             NVARCHAR(30)   = ''
         ,  @c_FromLottable11             NVARCHAR(30)   = ''
         ,  @c_FromLottable12             NVARCHAR(30)   = ''
         ,  @dt_FromLottable13            DATETIME       = NULL
         ,  @dt_FromLottable14            DATETIME       = NULL
         ,  @dt_FromLottable15            DATETIME       = NULL
         ,  @n_FromQty                    INT            = 0                         
         ,  @c_ToSku                      NVARCHAR(20)   = ''                
         ,  @c_ToPackkey                  NVARCHAR(10)   = ''
         ,  @c_ToUOM                      NVARCHAR(10)   = ''
         ,  @c_ToLot                      NVARCHAR(10)   = ''
         ,  @c_ToLoc                      NVARCHAR(10)   = ''
         ,  @c_ToID                       NVARCHAR(18)   = ''
         ,  @c_ToLottable01               NVARCHAR(18)   = ''
         ,  @c_ToLottable02               NVARCHAR(18)   = ''
         ,  @c_ToLottable03               NVARCHAR(18)   = ''
         ,  @dt_ToLottable04              DATETIME       = NULL
         ,  @dt_ToLottable05              DATETIME       = NULL
         ,  @c_ToLottable06               NVARCHAR(30)   = ''
         ,  @c_ToLottable07               NVARCHAR(30)   = ''
         ,  @c_ToLottable08               NVARCHAR(30)   = ''
         ,  @c_ToLottable09               NVARCHAR(30)   = ''
         ,  @c_ToLottable10               NVARCHAR(30)   = ''
         ,  @c_ToLottable11               NVARCHAR(30)   = ''
         ,  @c_ToLottable12               NVARCHAR(30)   = ''
         ,  @dt_ToLottable13              DATETIME       = NULL
         ,  @dt_ToLottable14              DATETIME       = NULL
         ,  @dt_ToLottable15              DATETIME       = NULL
         ,  @n_ToQty                      INT            = 0 
         ,  @c_Channel_Default            NVARCHAR(20)   = ''
         ,  @c_Channel_From               NVARCHAR(20)   = ''                        
         ,  @c_Channel_To                 NVARCHAR(20)   = ''
         ,  @c_FromSerialNo               NVARCHAR(50)   = ''  
         ,  @c_ToSerialNo                 NVARCHAR(50)   = ''           

         ,  @c_ASNFizUpdLotToSerialNo     NVARCHAR(10)   = ''
         ,  @c_ChannelInventoryMgmt_From  NVARCHAR(10)   = ''                           
         ,  @c_ChannelInventoryMgmt_To    NVARCHAR(10)   = ''         
         
         ,  @c_TableName                  NVARCHAR(50)   = 'TRANSFERDETAIL'
         ,  @c_SourceType                 NVARCHAR(50)   = 'lsp_TRF_PopulateSN_Wrapper'
         ,  @c_SourceKey                  NVARCHAR(50)   = ''
         ,  @c_SourceType_LARule          NVARCHAR(50)   = 'TRANSFER'
         ,  @c_Refkey1                    NVARCHAR(20)   = ''
         ,  @c_Refkey2                    NVARCHAR(20)   = ''
         ,  @c_Refkey3                    NVARCHAR(20)   = ''
         ,  @c_WriteType                  NVARCHAR(50)   = ''
         ,  @n_LogWarningNo               INT            = 0
         
         ,  @CUR_LLI                      CURSOR
         ,  @CUR_ERRLIST                  CURSOR   
         
   DECLARE  @t_WMSErrorList TABLE
         (  RowID             INT            IDENTITY(1,1)
         ,  TableName         NVARCHAR(10)   NOT NULL DEFAULT('')
         ,  SourceType        NVARCHAR(50)   NOT NULL DEFAULT('')
         ,  Refkey1           NVARCHAR(20)   NOT NULL DEFAULT('')
         ,  Refkey2           NVARCHAR(20)   NOT NULL DEFAULT('')
         ,  Refkey3           NVARCHAR(20)   NOT NULL DEFAULT('')
         ,  WriteType         NVARCHAR(50)   NOT NULL DEFAULT('')
         ,  LogWarningNo      INT            NOT NULL DEFAULT(0)
         ,  ErrCode           INT            NOT NULL DEFAULT(0)
         ,  Errmsg            NVARCHAR(255)  NOT NULL DEFAULT('')
         )                                                                                    
   SET @b_Success = 1
   SET @n_Err     = 0
               
   SET @n_Err = 0 
   IF SUSER_SNAME() <> @c_UserName        
   BEGIN
      EXEC [WM].[lsp_SetUser] @c_UserName = @c_UserName OUTPUT, @n_Err = @n_Err OUTPUT, @c_ErrMsg = @c_ErrMsg OUTPUT
    
      IF @n_Err <> 0 
      BEGIN
         GOTO EXIT_SP
      END
                
      EXECUTE AS LOGIN = @c_UserName        
   END                                    

   BEGIN TRY                                   
      SET @n_ErrGroupKey = 0

      SET @c_FromFacility = ''
      SET @c_FromStorerkey= ''
      SET @c_ToFacility = ''
      SET @c_ToStorerkey= ''
      SELECT @c_FromFacility = TH.Facility
            ,@c_ToFacility   = TH.ToFacility
            ,@c_FromStorerkey= TH.FromStorerkey
            ,@c_ToStorerkey  = TH.ToStorerkey
      FROM TRANSFER TH WITH (NOLOCK)
      WHERE TH.TransferKey = @c_TransferKey
  
      SELECT @c_ASNFizUpdLotToSerialNo = fsgr.Authority 
      FROM dbo.fnc_SelectGetRight(@c_FromFacility, @c_FromStorerkey, '', 'ASNFizUpdLotToSerialNo')AS fsgr
      SELECT @c_ChannelInventoryMgmt_From = fsgr.Authority 
      FROM dbo.fnc_SelectGetRight (@c_FromFacility, @c_FromStorerkey,'','ChannelInventoryMgmt') AS fsgr
      SELECT @c_ChannelInventoryMgmt_To   = fsgr.Authority 
      FROM dbo.fnc_SelectGetRight (@c_ToFacility, @c_ToStorerkey,'','ChannelInventoryMgmt') AS fsgr
 
      IF @c_ChannelInventoryMgmt_From = '1'
      BEGIN
         SELECT TOP 1 @c_Channel_Default = c.Code
         FROM dbo.CODELKUP AS c WITH (NOLOCK)
         WHERE c.ListName = 'Channel'
         AND c.Storerkey IN ('', @c_FromStorerkey)
         ORDER BY CASE WHEN c.Storerkey = @c_FromStorerkey THEN 1
                       ELSE 9
                       END
               ,  c.Code  
      END         
      /*-------------------------------------------------------*/
      /* BUILD TEMP TABLES & INSERT DATA - START               */
      /*-------------------------------------------------------*/
      IF OBJECT_ID('tempdb..#tSN', 'U') IS NOT NULL
      BEGIN
         DROP TABLE #tSN
      END
      
      CREATE TABLE #tSN 
         (  SerialNoKey NVARCHAR(10)   NOT NULL DEFAULT('')       PRIMARY KEY
         ,  Lot         NVARCHAR(20)   NOT NULL DEFAULT('')  
         )

      /*-------------------------------------------------------*/
      /* BUILD TEMP TABLES & INSERT DATA - END                 */
      /*-------------------------------------------------------*/

      SET @c_SelectSQL = 'SELECT SerialNo.SerialNoKey'
                       + ', ' +CASE WHEN @c_ASNFizUpdLotToSerialNo = '1' 
                                    THEN 'SerialNo.Lot'
                                    ELSE '''''' --'ISNULL(SerialNo.LotNo,'''')'
                                    END
      SELECT @c_SearchSQL = dbo.fnc_ParseSearchSQL(@c_SearchSQL, @c_SelectSQL) 

      IF @c_SearchSQL = ''
      BEGIN
         SET @n_Continue = 3
         SET @n_Err      = 562501
         SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Empty Search Criteria found. (lsp_TRF_PopulateSN_Wrapper)' 
      
         INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)
         VALUES (@c_TableName, @c_SourceType, @c_TransferKey, '', '', 'ERROR', 0, @n_Err, @c_Errmsg)  
         GOTO EXIT_SP                                                                          
      END                                                                               
      
      INSERT INTO #tSN ( SerialNoKey, Lot ) 
      EXEC sp_ExecuteSQL @c_SearchSQL                   
 
      SET @c_TransferLineNumber = '00000'  
    
      SELECT TOP 1 @c_TransferLineNumber = TD.TransferLineNumber
      FROM TRANSFERDETAIL TD WITH (NOLOCK)
      WHERE TD.Transferkey = @c_Transferkey
      ORDER BY TD.TransferLineNumber DESC

      SET @CUR_LLI = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT TOP 50000
             ltlci.StorerKey
            ,ltlci.Sku
            ,s.Packkey
            ,p.PackUOM3
            ,ltlci.lot
            ,ltlci.loc
            ,ltlci.id 
            ,QtyAvailable = sn.qty  
            ,l.Lottable01
            ,l.Lottable02
            ,l.Lottable03
            ,l.Lottable04
            ,l.Lottable05
            ,l.Lottable06
            ,l.Lottable07
            ,l.Lottable08
            ,l.Lottable09
            ,l.Lottable10
            ,l.Lottable11
            ,l.Lottable12
            ,l.Lottable13
            ,l.Lottable14
            ,l.Lottable15
            ,sn.SerialNo
      FROM #tSN AS ts 
      JOIN dbo.SerialNo AS sn (NOLOCK) ON sn.SerialNoKey = ts.SerialNoKey
      JOIN dbo.LOTxLOCxID AS ltlci (NOLOCK) ON  ltlci.Storerkey = sn.Storerkey
                                            AND ltlci.Sku = sn.Sku
                                            AND ltlci.ID  = sn.ID AND ltlci.ID <> ''
                                            AND ltlci.Lot = ts.Lot 
      JOIN dbo.LOTATTRIBUTE AS l (NOLOCK) ON l.Lot = ltlci.Lot                                    
      JOIN dbo.SKU AS s (NOLOCK) ON s.StorerKey = l.StorerKey AND s.Sku = l.Sku
      JOIN dbo.PACK AS p (NOLOCK) ON p.PackKey= s.PACKKey 
      WHERE ltlci.Qty - ltlci.Qtyallocated - ltlci.QtyPicked >= sn.qty
      AND s.SerialNoCapture IN ('1','2', '3')
      AND sn.[Status] = '1'
      AND sn.Qty = 1
      ORDER BY ltlci.lot, ltlci.loc, ltlci.id, sn.SerialNo
      
      OPEN @CUR_LLI
      FETCH NEXT FROM  @CUR_LLI INTO @c_FromStorerkey
                                    ,@c_FromSku
                                    ,@c_FromPackkey
                                    ,@c_FromUOM 
                                    ,@c_FromLot
                                    ,@c_FromLoc
                                    ,@c_FromID
                                    ,@n_FromQty
                                    ,@c_FromLottable01   
                                    ,@c_FromLottable02   
                                    ,@c_FromLottable03   
                                    ,@dt_FromLottable04  
                                    ,@dt_FromLottable05  
                                    ,@c_FromLottable06   
                                    ,@c_FromLottable07   
                                    ,@c_FromLottable08   
                                    ,@c_FromLottable09   
                                    ,@c_FromLottable10   
                                    ,@c_FromLottable11   
                                    ,@c_FromLottable12   
                                    ,@dt_FromLottable13  
                                    ,@dt_FromLottable14  
                                    ,@dt_FromLottable15
                                    ,@c_FromSerialNo  

      WHILE @@FETCH_STATUS <> -1 AND @n_Continue = 1
      BEGIN
         SET @c_ToSku         = @c_FromSku 
         SET @c_ToLot         = ''                                                  --2024-09-25
         SET @c_ToLoc         = @c_FromLoc
         SET @c_ToID          = @c_FromID
         SET @c_ToPackkey     = @c_FromPackkey    
         SET @c_ToUOM         = @c_FromUOM 
         SET @n_ToQty         = @n_FromQty
         SET @c_ToLottable01  = @c_FromLottable01 
         SET @c_ToLottable02  = @c_FromLottable02 
         SET @c_ToLottable03  = @c_FromLottable03 
         SET @dt_ToLottable04 = @dt_FromLottable04
         SET @dt_ToLottable05 = @dt_FromLottable05
         SET @c_ToLottable06  = @c_FromLottable06 
         SET @c_ToLottable07  = @c_FromLottable07 
         SET @c_ToLottable08  = @c_FromLottable08 
         SET @c_ToLottable09  = @c_FromLottable09 
         SET @c_ToLottable10  = @c_FromLottable10 
         SET @c_ToLottable11  = @c_FromLottable11 
         SET @c_ToLottable12  = @c_FromLottable12 
         SET @dt_ToLottable13 = @dt_FromLottable13
         SET @dt_ToLottable14 = @dt_FromLottable14
         SET @dt_ToLottable15 = @dt_FromLottable15
         SET @c_ToSerialNo    = @c_FromSerialNo
         
         IF @c_ChannelInventoryMgmt_From = '1'
         BEGIN
            SET @c_Channel_From = ''
            SELECT @c_Channel_From = fsci.Channel
            FROM dbo.fnc_SelectChannelInv(@c_FromFacility, @c_FromStorerkey, @c_FromSku, @c_Channel_From
                                         ,@c_FromLot, @n_FromQty
                                         ) AS fsci
         
            IF @c_Channel_From = ''
            BEGIN
               SET @c_Channel_From = @c_Channel_Default
            END
         END

         IF @c_ChannelInventoryMgmt_To = '1'
         BEGIN
            SET @c_Channel_To = @c_Channel_From
         END

         SET @c_TransferLineNumber = RIGHT( '00000' + CONVERT(NVARCHAR(5), CONVERT(INT, @c_TransferLineNumber) + 1), 5 )
 
         INSERT INTO TRANSFERDETAIL
               (  TransferKey
               ,  TransferLineNumber
               ,  FromStorerkey  
               ,  FromSku
               ,  FromPackkey  
               ,  FromUOM
               ,  FromQty
               ,  FromLot
               ,  FromLoc
               ,  FromID
               ,  Lottable01
               ,  Lottable02
               ,  Lottable03
               ,  Lottable04
               ,  Lottable05
               ,  Lottable06
               ,  Lottable07
               ,  Lottable08
               ,  Lottable09
               ,  Lottable10
               ,  Lottable11
               ,  Lottable12
               ,  Lottable13
               ,  Lottable14
               ,  Lottable15
               ,  ToStorerkey  
               ,  ToSku
               ,  ToPackkey  
               ,  ToUOM
               ,  ToQty
               ,  ToLot
               ,  ToLoc
               ,  ToID
               ,  ToLottable01
               ,  ToLottable02
               ,  ToLottable03
               ,  ToLottable04
               ,  ToLottable05
               ,  ToLottable06
               ,  ToLottable07
               ,  ToLottable08
               ,  ToLottable09
               ,  ToLottable10
               ,  ToLottable11
               ,  ToLottable12
               ,  ToLottable13
               ,  ToLottable14
               ,  ToLottable15
               ,  FromChannel                                                     
               ,  ToChannel   
               ,  FromSerialNo
               ,  ToSerialNo
               )
         VALUES(  @c_TransferKey
               ,  @c_TransferLineNumber
               ,  @c_FromStorerkey  
               ,  @c_FromSku
               ,  @c_FromPackkey  
               ,  @c_FromUOM
               ,  @n_FromQty
               ,  @c_FromLot
               ,  @c_FromLoc
               ,  @c_FromID
               ,  @c_FromLottable01
               ,  @c_FromLottable02
               ,  @c_FromLottable03
               ,  @dt_FromLottable04
               ,  @dt_FromLottable05
               ,  @c_FromLottable06
               ,  @c_FromLottable07
               ,  @c_FromLottable08
               ,  @c_FromLottable09
               ,  @c_FromLottable10
               ,  @c_FromLottable11
               ,  @c_FromLottable12
               ,  @dt_FromLottable13
               ,  @dt_FromLottable14
               ,  @dt_FromLottable15
               ,  @c_ToStorerkey  
               ,  @c_ToSku
               ,  @c_ToPackkey  
               ,  @c_ToUOM
               ,  @n_ToQty
               ,  @c_ToLot
               ,  @c_ToLoc
               ,  @c_ToID
               ,  @c_ToLottable01
               ,  @c_ToLottable02
               ,  @c_ToLottable03
               ,  @dt_ToLottable04
               ,  @dt_ToLottable05
               ,  @c_ToLottable06
               ,  @c_ToLottable07
               ,  @c_ToLottable08
               ,  @c_ToLottable09
               ,  @c_ToLottable10
               ,  @c_ToLottable11
               ,  @c_ToLottable12
               ,  @dt_ToLottable13
               ,  @dt_ToLottable14
               ,  @dt_ToLottable15
               ,  @c_Channel_From                                                
               ,  @c_Channel_To  
               ,  @c_FromSerialNo
               ,  @c_ToSerialNo
               )
 
         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 562502
            SET @c_ErrMsg = ERROR_MESSAGE()
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) 
                          + ': INSERT TRANSFERDETAIL Table Fail. (lsp_TRF_PopulateSN_Wrapper)'   
                          + '(' + @c_ErrMsg + ')' 

            INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)
            VALUES (@c_TableName, @c_SourceType, @c_TransferKey, '', '', 'ERROR', 0, @n_Err, @c_Errmsg)  
            GOTO EXIT_SP 
         END

         FETCH NEXT FROM  @CUR_LLI INTO @c_FromStorerkey
                                       ,@c_FromSku
                                       ,@c_FromPackkey
                                       ,@c_FromUOM 
                                       ,@c_FromLot
                                       ,@c_FromLoc
                                       ,@c_FromID
                                       ,@n_FromQty
                                       ,@c_FromLottable01   
                                       ,@c_FromLottable02   
                                       ,@c_FromLottable03   
                                       ,@dt_FromLottable04  
                                       ,@dt_FromLottable05  
                                       ,@c_FromLottable06   
                                       ,@c_FromLottable07   
                                       ,@c_FromLottable08   
                                       ,@c_FromLottable09   
                                       ,@c_FromLottable10   
                                       ,@c_FromLottable11   
                                       ,@c_FromLottable12   
                                       ,@dt_FromLottable13  
                                       ,@dt_FromLottable14  
                                       ,@dt_FromLottable15
                                       ,@c_FromSerialNo  
      END
      CLOSE @CUR_LLI
      DEALLOCATE @CUR_LLI
   END TRY
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg   = ERROR_MESSAGE() 

      INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)
      VALUES (@c_TableName, @c_SourceType, @c_TransferKey, '', '', 'ERROR', 0, @n_Err, @c_Errmsg)  
   END CATCH                               
EXIT_SP:                                   
   IF (XACT_STATE()) = -1                  
   BEGIN                                   
      SET @n_Continue = 3                  
      ROLLBACK TRAN                        
   END 
   
   IF OBJECT_ID('tempdb..#tSN', 'U') IS NOT NULL
   BEGIN
      DROP TABLE #tSN
   END
   
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_TRF_PopulateSN_Wrapper'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
     
   SET @CUR_ERRLIST = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT   twl.TableName
         ,  twl.SourceType
         ,  twl.Refkey1
         ,  twl.Refkey2
         ,  twl.Refkey3
         ,  twl.WriteType
         ,  twl.LogWarningNo
         ,  twl.ErrCode
         ,  twl.Errmsg
   FROM @t_WMSErrorList AS twl
   ORDER BY twl.RowID

   OPEN @CUR_ERRLIST

   FETCH NEXT FROM @CUR_ERRLIST INTO   @c_TableName
                                     , @c_SourceType
                                     , @c_Refkey1
                                     , @c_Refkey2
                                     , @c_Refkey3
                                     , @c_WriteType
                                     , @n_LogWarningNo
                                     , @n_Err
                                     , @c_Errmsg

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      EXEC [WM].[lsp_WriteError_List]
         @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
      ,  @c_TableName   = @c_TableName
      ,  @c_SourceType  = @c_SourceType
      ,  @c_Refkey1     = @c_Refkey1
      ,  @c_Refkey2     = @c_Refkey2
      ,  @c_Refkey3     = @c_Refkey3
      ,  @n_LogWarningNo= @n_LogWarningNo
      ,  @c_WriteType   = @c_WriteType
      ,  @n_err2        = @n_err
      ,  @c_errmsg2     = @c_errmsg
      ,  @b_Success     = @b_Success
      ,  @n_err         = @n_err
      ,  @c_errmsg      = @c_errmsg

      FETCH NEXT FROM @CUR_ERRLIST INTO   @c_TableName
                                        , @c_SourceType
                                        , @c_Refkey1
                                        , @c_Refkey2
                                        , @c_Refkey3
                                        , @c_WriteType
                                        , @n_LogWarningNo
                                        , @n_Err
                                        , @c_Errmsg
   END
   CLOSE @CUR_ERRLIST
   DEALLOCATE @CUR_ERRLIST

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END  
         
   REVERT
END

GO