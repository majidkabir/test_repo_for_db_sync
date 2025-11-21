SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store Procedure:  nspg_GetKey_AlphaSeq                               */  
/* Creation Date: 09-May-2012                                           */  
/* Copyright: IDS                                                       */  
/* Written by: MCTang                                                   */  
/*                                                                      */  
/* Purpose:  Get Key with AlphaSeq                                      */  
/*                                                                      */ 
/* Input Parameters:  @c_KeyName                                        */
/*                    @n_FieldLength                                    */
/*                    @b_ResultSet                                      */  
/*                    @n_Batch                                          */
/*                                                                      */  
/* Output Parameters: INT                                               */ 
/*                    @b_Success                                        */ 
/*                    @n_Err                                            */
/*                    @c_ErrMsg                                         */
/*                                                                      */ 
/* Usage:                                                               */
/*                                                                      */  
/* Called By:                                                           */
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/************************************************************************/  

CREATE PROC [dbo].[nspg_GetKey_AlphaSeq]     
               @c_KeyName     NVARCHAR(18)    
,              @n_FieldLength INT    
,              @c_KeyString   NVARCHAR(25)   OUTPUT    
,              @b_Success     INT        OUTPUT    
,              @n_Err         INT        OUTPUT    
,              @c_ErrMsg      NVARCHAR(250)  OUTPUT    
,              @b_ResultSet   INT        = 0    
,              @n_Batch       INT        = 1    
AS    
    
   SET NOCOUNT ON     
   SET QUOTED_IDENTIFIER OFF     
   SET ANSI_NULLS OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @n_count        INT /* next key */    
   DECLARE @n_ncnt         INT    
   DECLARE @n_StarttCnt    INT /* Holds the current transaction count */    
   DECLARE @n_Continue     INT /* Continuation flag: 1=Continue, 2=failed but continue processsing, 3=failed do not continue processing, 4=successful but skip furthur processing */    
   DECLARE @n_Cnt          INT /* Variable to record if @@ROWCOUNT=0 after UPDATE */
   DECLARE @c_BigString    NVARCHAR(50)     
   DECLARE @c_Alpha        NVARCHAR(10) 
         , @n_AlphaLen     INT
         , @c_AlphaOut     NVARCHAR(10)
         , @c_AlphaCurr    NVARCHAR(10)         
         , @c_UpdatePrev   NVARCHAR(1)
         , @n_LoopCnt      INT
      
   SELECT @n_StarttCnt=@@TRANCOUNT, @n_Continue=1, @b_success=0, @n_Err=0, @c_ErrMsg=''    
      
   BEGIN TRANSACTION     
   
   UPDATE nCounter WITH (ROWLOCK) 
   SET KeyCount = KeyCount 
   WHERE KeyName = @c_KeyName    
   
   SELECT @n_Err = @@ERROR, @n_Cnt = @@ROWCOUNT    
   IF @n_Err <> 0    
   BEGIN    
      SELECT @n_Continue = 3     
   END    
       
   IF @n_Continue = 1 or @n_Continue = 2    
   BEGIN    
      IF @n_Cnt > 0    
      BEGIN    
         -- Start - Added by YokeBeen on 7-Apr-2003 for HongKong Timberland's Project.    
         -- To reset the Counter.    
         IF @n_FieldLength < 10    
         BEGIN    
         
            SELECT @n_count = KeyCount 
                 , @c_Alpha = ISNULL(RTRIM(AlphaCount), '')
            FROM nCounter WITH (NOLOCK)
            WHERE KeyName = @c_KeyName 
         
            SELECT @n_AlphaLen = Len(@c_Alpha)
            
            --IF EXISTS (SELECT 1 FROM nCounter WITH (NOLOCK) 
            --           WHERE KeyName = @c_KeyName 
            --           And KeyCount = RIGHT(REPLICATE('9', @n_FieldLength), @n_FieldLength) )
            
            IF @n_count = RIGHT(REPLICATE('9', @n_FieldLength-@n_AlphaLen), @n_FieldLength-@n_AlphaLen)    
            BEGIN    
            
               SET @c_AlphaOut = ''
               SET @c_UpdatePrev = ''
               
               IF @c_Alpha = ''
               BEGIN
                  SELECT @c_AlphaOut = 'A'
               END
               ELSE IF @c_Alpha = RIGHT(REPLICATE('Z', @n_AlphaLen), @n_AlphaLen)
               BEGIN   
                  SELECT @c_AlphaOut = RIGHT(REPLICATE('A', @n_AlphaLen), @n_AlphaLen) + 'A'
               END
               ELSE
               BEGIN
                  SET @n_LoopCnt = 1  

                  WHILE @n_LoopCnt <= @n_AlphaLen 
                  BEGIN 
                     
                     SELECT @c_AlphaCurr = SUBSTRING(@c_Alpha, @n_AlphaLen-@n_LoopCnt+1, 1)
                   
                     IF @n_LoopCnt = 1
                     BEGIN
                        IF ASCII(@c_AlphaCurr) = 90
                        BEGIN
                           SET @c_UpdatePrev = 'Y'
                           SET @c_AlphaCurr = 'A' 
                        END
                        ELSE
                        BEGIN
                           SET @c_AlphaCurr = master.dbo.fnc_GetCharASCII(ASCII(@c_AlphaCurr) + 1) 
                        END 
                     END  -- IF @n_LoopCnt = 1
                     ELSE -- IF @n_LoopCnt <> 1
                     BEGIN
                        IF @c_UpdatePrev = 'Y'
                        BEGIN
                           SET @c_UpdatePrev = ''
                           IF ASCII(@c_AlphaCurr) = 90
                           BEGIN
                              SET @c_UpdatePrev = 'Y'
                              SET @c_AlphaCurr = 'A' 
                           END  -- IF @c_UpdatePrev = 'Y'
                           ELSE -- IF @c_UpdatePrev <> 'Y'
                           BEGIN
                              SET @c_AlphaCurr = master.dbo.fnc_GetCharASCII(ASCII(@c_AlphaCurr) + 1) 
                           END
                        END
                     END
                     
                     SET @c_AlphaOut = @c_AlphaCurr + @c_AlphaOut 
                              
                     SET @n_LoopCnt = @n_LoopCnt + 1
                  END
               END                  
            
               UPDATE nCounter WITH (ROWLOCK) 
               SET KeyCount = 0 
                 , AlphaCount = @c_AlphaOut
               WHERE KeyName = @c_KeyName    
               SELECT @n_Err = @@ERROR, @n_Cnt = @@ROWCOUNT        
            END    
         END    
         -- Ended on 7-Apr-2003 for HongKong Timberland's Project.    
       
         UPDATE nCounter WITH (ROWLOCK) 
         SET KeyCount = KeyCount + @n_Batch 
         WHERE KeyName = @c_KeyName    
         SELECT @n_Err = @@ERROR, @n_Cnt = @@ROWCOUNT    
       
         IF @n_Err <> 0    
         BEGIN 
             SELECT @n_Continue = 3     
             SELECT @c_ErrMsg = CONVERT(char(250),@n_Err), @n_Err=61900   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
             SELECT @c_ErrMsg = 'NSQL' + CONVERT(char(5),@n_Err) + ': Update Failed On nCounter:' + @c_KeyName 
                              + '. (nspg_GetKey_AlphaSeq)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_ErrMsg)) + ' ) '    
         END    
         ELSE IF @n_Cnt = 0    
         BEGIN    
            SELECT @n_Continue = 3     
            SELECT @n_Err = 61901    
            SELECT @c_ErrMsg = 'NSQL' + CONVERT(char(5),@n_Err) + ': Update To Table nCounter:' + @c_KeyName 
                             + ' Returned Zero Rows Affected. (nspg_GetKey_AlphaSeq)'    
         END    
      END    
      ELSE 
      BEGIN    
      
         INSERT nCounter (KeyName, KeyCount, AlphaCount) VALUES (@c_KeyName, @n_Batch, '')       

         SELECT @n_Err = @@ERROR    
         IF @n_Err <> 0    
         BEGIN    
             SELECT @n_Continue = 3     
             SELECT @c_ErrMsg = CONVERT(char(250),@n_Err), @n_Err=61902   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
             SELECT @c_ErrMsg = 'NSQL' + CONVERT(char(5),@n_Err) + ': Insert Failed On nCounter:' + @c_KeyName 
                              + '. (nspg_GetKey_AlphaSeq)' + '( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_ErrMsg)) + ' ) '    
         END
         
     END    

     IF @n_Continue=1 OR @n_Continue=2    
     BEGIN  
       
         SELECT @n_count = KeyCount - @n_Batch 
              , @c_Alpha = ISNULL(RTRIM(AlphaCount), '')
         FROM nCounter WITH (NOLOCK)
         WHERE KeyName = @c_KeyName 
            
         SELECT @c_KeyString = RTRIM(LTRIM(CONVERT(char(18),@n_count + 1)))    
         
         SELECT @c_BigString = Rtrim(@c_KeyString)    
         SELECT @c_BigString = Replicate('0',25) + @c_BigString   
         
         IF ISNULL(@c_Alpha, '') <> ''
         BEGIN
            SELECT @n_AlphaLen = 0
            SELECT @n_AlphaLen = Len(@c_Alpha)
            SELECT @c_BigString = @c_Alpha + RIGHT(Rtrim(@c_BigString), @n_FieldLength - @n_AlphaLen)    
         END
         ELSE
         BEGIN
            SELECT @c_BigString = RIGHT(Rtrim(@c_BigString), @n_FieldLength)            
         END
         
         SELECT @c_KeyString = Rtrim(@c_BigString)    
         
         IF @b_ResultSet = 1    
         BEGIN    
             SELECT @c_KeyString 'c_keystring', @b_Success 'b_success', @n_Err 'n_err', @c_ErrMsg 'c_errmsg'     
         END    
     END    
   END    

IF @n_Continue=3  -- Error Occured - Process And Return    
BEGIN    

   SELECT @b_success = 0         
   IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StarttCnt     
   BEGIN    
      ROLLBACK TRAN    
   END    
   ELSE 
   BEGIN    
      WHILE @@TRANCOUNT > @n_StarttCnt     
      BEGIN    
         COMMIT TRAN    
      END              
   END    
   
   EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'nsp_getkey'    
   RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
   RETURN   
END    
ELSE 
BEGIN    
   SELECT @b_success = 1    
   WHILE @@TRANCOUNT > @n_StarttCnt     
   BEGIN    
      COMMIT TRAN    
   END    
   RETURN    
END

GO