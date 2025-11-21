SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Stored Procedure:  nspg_GetKey2                                      */    
/* Creation Date:                                                       */    
/* Copyright: IDS                                                       */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose:  Call from nspg_GetKey                                      */    
/*                                                                      */    
/************************************************************************/   

CREATE PROCEDURE  [dbo].[nspg_GetKey2]  
    @c_KeyName        NVARCHAR(50)  
,   @c_Prefixed       VARCHAR(5) = ''           
,   @n_FieldLength    INT = 0   
,   @c_Keystring      NVARCHAR(25)   OUTPUT    
,   @b_Success        INT            OUTPUT    
,   @n_Err            INT            OUTPUT    
,   @c_Errmsg         NVARCHAR(250)  OUTPUT    
,   @b_ResultSet      INT       = 0    
,   @n_Batch          INT       = 1    
AS
BEGIN
SET NOCOUNT ON     
SET ANSI_NULLS OFF    
SET QUOTED_IDENTIFIER OFF     
SET CONCAT_NULL_YIELDS_NULL OFF    
                
   DECLARE 
     @n_Count     INT, /* next key */  
     @n_Counter   INT, 
     @c_BigString VARCHAR(25), 
     @n_StartTCnt INT 

   DECLARE @c_StoredProcName SYSNAME
   SET @c_StoredProcName = OBJECT_NAME(@@PROCID)
                                
   SET @n_StartTCnt = @@TRANCOUNT;
   SET @c_Keystring = ''
                                
   DECLARE @n_Continue int /* Continuation flag: 
                              1=Continue, 
                              2=failed but continue processsing, 
                              3=failed do not continue processing, 
                              4=successful but skip furthur processing */    

   IF OBJECT_ID('dbo.' + @c_KeyName) IS NULL
   BEGIN
      SET @n_Continue = 3     
      SET @n_Err=61900       
      SET @c_Errmsg='ERROR:'+CONVERT(varchar(5),@n_Err)+': Object dbo.' + @c_KeyName + ' not found database'
      GOTO QUIT_SP                        
   END
   
   DECLARE @c_SQL NVARCHAR(2000)
   
   SET @c_SQL = N'SELECT @nCount = NEXT VALUE FOR dbo.' + @c_KeyName 
   SET @n_Counter = 0
                 
   WHILE @n_Counter < @n_Batch
   BEGIN
       EXEC sys.sp_executesql @c_SQL, N'@nCount BIGINT OUTPUT', @n_Count OUTPUT 
       IF @@ERROR = 0 
       BEGIN
          SET @n_Counter = @n_Counter + 1             
       END
       ELSE 
       BEGIN
          SET @n_Continue = 3  
          SET @c_Errmsg = 'GetKey ' + @c_KeyName + ' failed'                                           
       END     
   END 
   
   SET @c_BigString = CAST(@n_Count AS VARCHAR(25))  
   SET @c_BigString = RIGHT(Replicate('0',25) + RTRIM(@c_BigString), 25)
   SET @n_FieldLength = @n_FieldLength - LEN(RTRIM(@c_Prefixed))          
   SET @c_BigString = RIGHT(RTRIM(@c_BigString), @n_FieldLength)   
   SET @c_Keystring = ISNULL(RTRIM(@c_Prefixed),'') + Rtrim(@c_BigString)    
          
   QUIT_SP:
   IF @n_Continue=3  -- Error Occured - Process And Return    
   BEGIN    
      SELECT @b_Success = 0         
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt     
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
    
      EXECUTE dbo.nsp_logerror @n_Err, @c_Errmsg, 'nspg_GetKey2'    
      RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR      
      RETURN        
   END    
   ELSE     
   BEGIN    
      SELECT @b_Success = 1    
      WHILE @@TRANCOUNT > @n_StartTCnt     
      BEGIN    
         COMMIT TRAN    
      END    
      RETURN        
   END
END

GO