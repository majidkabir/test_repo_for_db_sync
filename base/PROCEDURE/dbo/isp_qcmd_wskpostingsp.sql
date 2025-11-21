SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE PROC [dbo].[isp_QCmd_WSKPostingSP]
(
   @c_LocalEndPoint     NVARCHAR(50)  
,  @c_RemoteEndPoint    NVARCHAR(50)  
,  @c_RespondMsg        NVARCHAR(MAX)  
,  @b_Success           INT            OUTPUT
,  @n_Err               INT            OUTPUT
,  @c_ErrMsg            NVARCHAR(256)  OUTPUT

)
AS
BEGIN
   
   INSERT INTO WebSocket_INLog (Application, LocalEndPoint, RemoteEndPoint, StorerKey, Data, Status) 
   VALUES ('QCMD_WSK', @c_LocalEndPoint, @c_RemoteEndPoint, 'UNKNOWN', @c_RespondMsg, '9')
   
   --SELECT * FROM WebSocket_INLog (NOLOCK)
END -- End of Procedure

GO