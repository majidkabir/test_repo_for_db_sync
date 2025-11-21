SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/      
/* Stored Procedure: lsp_UnpickSerialNo_Wrapper                         */      
/* Creation Date: 2024-12-02                                            */      
/* Copyright: Mersk logistics                                           */      
/* Written by:                                                          */      
/*                                                                      */      
/* Purpose: Pick Serial No Unpick                                       */      
/*                                                                      */      
/* Called By: Unallocation                                              */      
/*                                                                      */      
/* Version: 1.0                                                         */      
/*                                                                      */      
/* Data Modifications:                                                  */      
/*                                                                      */      
/* Updates:                                                             */      
/* Date        Author   Ver   Purposes                                  */      
/************************************************************************/       
CREATE   PROCEDURE [WM].[lsp_UnpickSerialNo_Wrapper]
   @c_Storerkey         NVARCHAR(15)  = ''         
,  @n_PickSerialNoKey   BIGINT        = 0        --optional      
,  @c_Orderkey          NVARCHAR(10)  = ''       --optional
,  @c_Wavekey           NVARCHAR(10)  = ''       --optional
,  @c_Action            NVARCHAR(15)  = 'UNPICK' -- UNPICK or UnPickAlloc
,  @b_Success           INT           = 1       OUTPUT     
,  @n_Err               INT           = 0       OUTPUT    
,  @c_ErrMsg            NVARCHAR(250) = ''      OUTPUT    
,  @c_UserName          NVARCHAR(128) = ''    
AS    
BEGIN     
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
   
   DECLARE @n_Continue              INT            = 1   
         , @n_Starttcnt             INT            = @@TRANCOUNT
         
         , @c_PickDetailKey_New     NVARCHAR(10)   = ''  
         , @c_PickDetailKey         NVARCHAR(10)   = '' 
         , @c_OrderLineNumber       NVARCHAR(5)   = ''               

         , @cur_PSNDEL              CURSOR

   SET @b_success = 1
   SET @n_Err     = 0
   SET @c_errmsg  = ''
   SET @n_PickSerialNoKey = ISNULL(@n_PickSerialNoKey,0)
   SET @c_Orderkey = ISNULL(@c_Orderkey,'')
      
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
      IF @@TRANCOUNT = 0
      BEGIN 
         BEGIN TRAN
      END

      IF @n_Continue IN (1,2)    
      BEGIN          
         IF @n_PickSerialNoKey = 0 AND @c_Orderkey = '' AND @c_Wavekey = ''
         BEGIN    
            SET @n_continue = 3      
            SET @n_Err = 562901    
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) +     
                          + ': PickSerialNo & Shipment Order key parameters are empty. (lsp_UnpickSerialNo_Wrapper)'    
         END           
      END 
      
      IF @n_Continue IN (1,2)  
      BEGIN
         IF @c_Orderkey > ''
         BEGIN
            SET @cur_PSNDEL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT psn.PickSerialNoKey, pd.PickDetailKey, pd.Orderkey, pd.OrderLineNumber
            FROM dbo.PickDetail pd (NOLOCK)
            JOIN dbo.PickSerialNo psn (NOLOCK) ON psn.Pickdetailkey = pd.PickdetailKey
            WHERE pd.Orderkey = @c_Orderkey
            AND psn.SerialNo > ''
            ORDER BY psn.PickSerialNoKey
         END
         ELSE IF @c_Wavekey > ''
         BEGIN
         SET @cur_PSNDEL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT psn.PickSerialNoKey, pd.PickDetailKey, pd.Orderkey, pd.OrderLineNumber
            FROM dbo.PickDetail pd (NOLOCK)
            JOIN dbo.PickSerialNo psn (NOLOCK) ON psn.Pickdetailkey = pd.PickdetailKey
            JOIN dbo.WaveDetail wd(nolock) on wd.OrderKey = pd.OrderKey
            WHERE wd.WaveKey = @c_Wavekey
            AND psn.SerialNo > ''
            ORDER BY psn.PickSerialNoKey
         END
         ELSE IF @n_PickSerialNoKey > 0
         BEGIN
            SET @cur_PSNDEL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT psn.PickSerialNoKey, pd.PickDetailKey, pd.Orderkey, pd.OrderLineNumber
            FROM dbo.PickDetail pd (NOLOCK)
            JOIN dbo.PickSerialNo psn (NOLOCK) ON psn.Pickdetailkey = pd.PickdetailKey
            WHERE psn.PickSerialNoKey = @n_PickSerialNoKey
            AND psn.SerialNo > ''
            ORDER BY psn.PickSerialNoKey
         END
            
         OPEN @cur_PSNDEL

         FETCH NEXT FROM @cur_PSNDEL INTO @n_PickSerialNoKey, @c_PickdetailKey
                                       ,  @c_Orderkey, @c_OrderLineNumber

         WHILE @@FETCH_STATUS <> -1 AND @n_Continue IN (1,2)
         BEGIN
            DELETE PickSerialNo WITH (ROWLOCK)
            WHERE PickSerialNoKey = @n_PickSerialNoKey

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
            END

            IF @n_Continue IN (1,2) AND @c_Action = 'UnPickAlloc' 
            BEGIN 
               SET @c_PickdetailKey_New = ''
               IF EXISTS ( SELECT 1 FROM PickSerialNo psn (NOLOCK)
                           WHERE psn.PickdetailKey = @c_PickdetailKey
                         )
               BEGIN 
                  SELECT @c_PickdetailKey_New = pd.PickDetailKey
                  FROM PICKDETAIL pd (NOLOCK)
                  WHERE pd.Orderkey  = @c_Orderkey
                  AND   pd.OrderLineNumber = @c_OrderLineNumber
                  AND   pd.[Status]  = '0'
               END
               ELSE
               BEGIN
                  SET @c_PickdetailKey_New = @c_PickdetailKey
               END
               
               IF @c_PickdetailKey_New > ''
               BEGIN
                  DELETE PICKDETAIL WITH (ROWLOCK)
                  WHERE PickdetailKey = @c_PickdetailKey_New
                  
                  IF @@ERROR <> 0
                  BEGIN
                     SET @n_Continue = 3
                  END
               END
            END
            IF @n_Continue IN (1,2) AND @c_Action = 'UNPICK' 
            BEGIN 
               SET @c_PickdetailKey_New = ''
               IF EXISTS ( SELECT 1 FROM PickSerialNo psn (NOLOCK)
                           WHERE psn.PickdetailKey = @c_PickdetailKey
                         )
               BEGIN 
                  SELECT @c_PickdetailKey_New = pd.PickDetailKey
                  FROM PICKDETAIL pd (NOLOCK)
                  WHERE pd.Orderkey  = @c_Orderkey
                  AND   pd.OrderLineNumber = @c_OrderLineNumber
                  AND   pd.[Status]  = '0'
               END
               ELSE
               BEGIN
                  SET @c_PickdetailKey_New = @c_PickdetailKey
               END
            
               IF @c_PickdetailKey_New > ''
               BEGIN
                  UPDATE PICKDETAIL SET STATUS = '0' 
                  WHERE PickdetailKey = @c_PickdetailKey_New
                  
                  IF @@ERROR <> 0
                  BEGIN
                     SET @n_Continue = 3
                  END
               END
            END
            FETCH NEXT FROM @cur_PSNDEL INTO @n_PickSerialNoKey, @c_PickdetailKey
                                          ,  @c_Orderkey, @c_OrderLineNumber
         END
         CLOSE @cur_PSNDEL
         DEALLOCATE @cur_PSNDEL
      END
   END TRY      
      
   BEGIN CATCH    
      SET @n_Continue = 3                            
      SET @c_ErrMsg = ERROR_MESSAGE()              
      GOTO EXIT_SP      
   END CATCH      
    
   EXIT_SP:     
   IF (XACT_STATE()) = -1      
   BEGIN    
      SET @n_Continue = 3     
      ROLLBACK TRAN    
   END      
       
   IF @n_continue=3  -- Error Occured - Process And Return      
   BEGIN      
      SELECT @b_success = 0      
      IF @n_Starttcnt = 0 AND @@TRANCOUNT > @n_Starttcnt              
      BEGIN      
         ROLLBACK TRAN      
      END      
      ELSE      
      BEGIN      
         WHILE @@TRANCOUNT > @n_starttcnt      
         BEGIN      
            COMMIT TRAN      
         END      
      END      
      Execute nsp_logerror @n_err, @c_errmsg, 'lsp_UnpickSerialNo_Wrapper'      
   END      
   ELSE      
   BEGIN      
      SELECT @b_success = 1      
      WHILE @@TRANCOUNT > @n_Starttcnt      
      BEGIN      
         COMMIT TRAN      
      END      
   END     
    
   WHILE @@TRANCOUNT < @n_Starttcnt                                    
   BEGIN    
      BEGIN TRAN    
   END                                                                
   REVERT                                                                        
END    

GO