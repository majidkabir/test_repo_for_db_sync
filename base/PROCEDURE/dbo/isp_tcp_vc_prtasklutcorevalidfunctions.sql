SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_TCP_VC_prTaskLUTCoreValidFunctions             */
/* Creation Date: 26-Feb-2013                                           */
/* Copyright: IDS                                                       */
/* Written by: Shong                                                    */
/*                                                                      */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/* 11-04-2013   ChewKP    Revise (ChewKP01)                             */  
/************************************************************************/
CREATE PROC [dbo].[isp_TCP_VC_prTaskLUTCoreValidFunctions] (
    @c_TranDate     NVARCHAR(20)
   ,@c_DevSerialNo  NVARCHAR(20)
   ,@c_OperatorID   NVARCHAR(20)
   ,@c_VoiceAppId   NVARCHAR(10)
   ,@n_SerialNo     INT
   ,@c_RtnMessage   NVARCHAR(500) = '' OUTPUT    
   ,@b_Success      INT = 1 OUTPUT
   ,@n_Error        INT = 0 OUTPUT
   ,@c_ErrMsg       NVARCHAR(255) = '' OUTPUT    
)
AS
BEGIN
   -- Valid Function No 
   --    01 = Put Away
   --    02 = Replenishment
   --    03 = Normal Assignments
   --    04 = Chase Assignments
   --    05 = No longer used
   --    06 = Normal and Chase Assignments
   --    07 = Line Loading
   --    08 = Put-to-Store
   --    09 = Cycle Counting
   --    10 = Loading
   --    11 = Back Stocking
   --    12 = Receiving
   
   DECLARE @c_FunctionNo        NVARCHAR(2) -- A descriptive name for the vehicle type
         , @c_FunctionName      NVARCHAR(100)
         , @c_CaptureVehType    NVARCHAR(1)
         , @c_ErrorCode         NVARCHAR(20)
         , @c_Message           NVARCHAR(400)
         , @c_LangCode          NVARCHAR(10)    
         , @c_Code              NVARCHAR(30)
         
   SET @c_ErrorCode = 0 
   SET @c_Message = ''
   SET @c_LangCode = ''
   
   SELECT @c_LangCode = r.DefaultLangCode        
   FROM rdt.RDTUser r (NOLOCK)        
   WHERE r.UserName = @c_OperatorID      
             
            
   
   -- Using CodeLKup UDF05 AS Vocollect Function No
   DECLARE CUR_FunctionPermission CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT DISTINCT RTRIM(C.Short) , 
          CASE WHEN RTRIM(@c_LangCode) = 'CHN' THEN RTRIM(C.[UDF01]) ELSE RTRIM(C.[Description]) END 
   FROM TaskManagerUserDetail tmud WITH (NOLOCK) 
   JOIN CODELKUP c WITH (NOLOCK) ON c.Code = tmud.PermissionType AND c.LISTNAME = 'PERMTYPE' 
   WHERE tmud.Permission = '1' 
   AND tmud.UserKey = @c_OperatorID 
   
   --ORDER BY C.Short
   
   SET @c_RtnMessage = ''
   
   OPEN CUR_FunctionPermission
   FETCH NEXT FROM CUR_FunctionPermission INTO @c_Code, @c_FunctionName
   
   WHILE @@FETCH_STATUS<> -1
   BEGIN
--      SET @c_FunctionName = CASE CAST(@c_FunctionNo AS INT)
--                               WHEN 1  THEN '1, Put Away,0,'
--                               WHEN 2  THEN '2, Replenishment,0,'
--                               WHEN 3  THEN '3, Normal Assignments,0,'
--                               WHEN 4  THEN '4, Chase Assignments,0,'
--                               WHEN 5  THEN '5, No longer used,0,'
--                               WHEN 6  THEN '6, Normal and Chase Assignments,0,'
--                               WHEN 7  THEN '7, Line Loading,0,'
--                               WHEN 8  THEN '8, Put-to-Store,0,'
--                               WHEN 9  THEN '9, Cycle Counting,0,'
--                               WHEN 10 THEN '10, Loading,0,'
--                               WHEN 11 THEN '11, Back Stocking,0,'
--                               WHEN 12 THEN '12, Receiving,0,'
--                               ELSE ''
--                            END
      
      IF ISNULL(@c_FunctionName, '') <> '' 
      BEGIN
         SET @c_RtnMessage = CASE WHEN LEN(@c_RtnMessage) = 0 THEN '' ELSE @c_RtnMessage + ',0,' + '<CR><LF>' END + 
                             ISNULL(RTRIM(@c_Code)        ,'') + ',' +           
                             ISNULL(RTRIM(@c_FunctionName),'') + ',' +     
                             ISNULL(RTRIM(@c_ErrorCode)   ,'') + ',' +           
                             ISNULL(RTRIM(@c_Message)     ,'')       
      END                     
              
      FETCH NEXT FROM CUR_FunctionPermission INTO @c_Code, @c_FunctionName
   END
   CLOSE CUR_FunctionPermission
   DEALLOCATE CUR_FunctionPermission
   
   
   
   IF LEN(RTRIM(ISNULL(@c_RtnMessage,''))) = 0 
   BEGIN
      SET @c_ErrorCode = '89'
      SET @c_Message = 'No Function Assigned'
      SET @c_RtnMessage =',,0,'
   END
   
   
   -- Temporary Only Picking process
   -- SET @c_RtnMessage = '3, Normal Assignments,0,' 
   

END

GO