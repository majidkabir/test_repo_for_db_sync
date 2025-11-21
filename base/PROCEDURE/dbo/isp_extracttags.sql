SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_ExtractTags                                         */
/* Creation Date: 2023-01-05                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose:  WMS-21467- [CN]NIKE_Ecom_NFC RFID Receiving-CR             */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2023-01-05  Wan      1.0   Created & DevOps Combine Script           */
/************************************************************************/
CREATE   PROC isp_ExtractTags
  @c_TagReader          NVARCHAR(10)           
, @c_TagData1           NVARCHAR(1000)
, @c_TagData2           NVARCHAR(1000) = ''
, @c_TagData3           NVARCHAR(1000) = ''
, @c_TagData4           NVARCHAR(1000) = ''
, @c_TagData5           NVARCHAR(1000) = ''
, @n_SeqNo1             INT = 0              OUTPUT
, @c_TidNo1             NVARCHAR(100)  = ''  OUTPUT
, @c_RFIDNo1            NVARCHAR(100)  = ''  OUTPUT
, @n_SeqNo2             INT = 0              OUTPUT
, @c_TidNo2             NVARCHAR(100)  = ''  OUTPUT
, @c_RFIDNo2            NVARCHAR(100)  = ''  OUTPUT
, @n_SeqNo3             INT = 0              OUTPUT
, @c_TidNo3             NVARCHAR(100)  = ''  OUTPUT
, @c_RFIDNo3            NVARCHAR(100)  = ''  OUTPUT
, @n_SeqNo4             INT = 0              OUTPUT
, @c_TidNo4             NVARCHAR(100)  = ''  OUTPUT
, @c_RFIDNo4            NVARCHAR(100)  = ''  OUTPUT
, @n_SeqNo5             INT = 0              OUTPUT
, @c_TidNo5             NVARCHAR(100)  = ''  OUTPUT
, @c_RFIDNo5            NVARCHAR(100)  = ''  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT = @@TRANCOUNT
         , @n_Continue        INT = 1
         , @c_Exec_SP         NVARCHAR(30) = ''
         
         , @c_SQL             NVARCHAR(1000) = ''
         , @c_SQLParms        NVARCHAR(1000) = ''         

   IF @c_TagReader = 'rfid'
   BEGIN
      SET @c_Exec_SP = 'isp_RFID_ExtractTags'
   END
   
   IF @c_TagReader = 'nfc'
   BEGIN
      SET @c_Exec_SP = 'isp_NFC_ExtractTags'
   END
   
   IF @c_Exec_SP <> ''
   BEGIN
      SET @c_SQL = N'EXEC ' + @c_Exec_SP 
                 + ' @c_TagData1  = @c_TagData1'
                 + ',@c_TagData2  = @c_TagData2'
                 + ',@c_TagData3  = @c_TagData3'
                 + ',@c_TagData4  = @c_TagData4'
                 + ',@c_TagData5  = @c_TagData5'
                 + ',@n_SeqNo1    = @n_SeqNo1    OUTPUT'
                 + ',@c_TidNo1    = @c_TidNo1    OUTPUT'
                 + ',@c_RFIDNo1   = @c_RFIDNo1   OUTPUT'
                 + ',@n_SeqNo2    = @n_SeqNo2    OUTPUT'
                 + ',@c_TidNo2    = @c_TidNo2    OUTPUT'
                 + ',@c_RFIDNo2   = @c_RFIDNo2   OUTPUT'
                 + ',@n_SeqNo3    = @n_SeqNo3    OUTPUT'
                 + ',@c_TidNo3    = @c_TidNo3    OUTPUT'
                 + ',@c_RFIDNo3   = @c_RFIDNo3   OUTPUT'
                 + ',@n_SeqNo4    = @n_SeqNo4    OUTPUT'
                 + ',@c_TidNo4    = @c_TidNo4    OUTPUT'
                 + ',@c_RFIDNo4   = @c_RFIDNo4   OUTPUT'
                 + ',@n_SeqNo5    = @n_SeqNo5    OUTPUT'
                 + ',@c_TidNo5    = @c_TidNo5    OUTPUT'
                 + ',@c_RFIDNo5   = @c_RFIDNo5   OUTPUT'
                 
      SET @c_SQLParms = N' @c_TagData1 NVARCHAR(1000)'
                      +  ',@c_TagData2 NVARCHAR(1000)'
                      +  ',@c_TagData3 NVARCHAR(1000)'
                      +  ',@c_TagData4 NVARCHAR(1000)'
                      +  ',@c_TagData5 NVARCHAR(1000)'
                      +  ',@n_SeqNo1   INT            OUTPUT'
                      +  ',@c_TidNo1   NVARCHAR(100)  OUTPUT'
                      +  ',@c_RFIDNo1  NVARCHAR(100)  OUTPUT'
                      +  ',@n_SeqNo2   INT            OUTPUT'
                      +  ',@c_TidNo2   NVARCHAR(100)  OUTPUT'
                      +  ',@c_RFIDNo2  NVARCHAR(100)  OUTPUT'
                      +  ',@n_SeqNo3   INT            OUTPUT'
                      +  ',@c_TidNo3   NVARCHAR(100)  OUTPUT'
                      +  ',@c_RFIDNo3  NVARCHAR(100)  OUTPUT'
                      +  ',@n_SeqNo4   INT            OUTPUT'
                      +  ',@c_TidNo4   NVARCHAR(100)  OUTPUT'
                      +  ',@c_RFIDNo4  NVARCHAR(100)  OUTPUT'
                      +  ',@n_SeqNo5   INT            OUTPUT'
                      +  ',@c_TidNo5   NVARCHAR(100)  OUTPUT'
                      +  ',@c_RFIDNo5  NVARCHAR(100)  OUTPUT' 
                      
      EXEC sp_ExecuteSQL @c_SQL  
                     , @c_SQLParms 
                     , @c_TagData1  
                     , @c_TagData2  
                     , @c_TagData3  
                     , @c_TagData4  
                     , @c_TagData5  
                     , @n_SeqNo1    OUTPUT
                     , @c_TidNo1    OUTPUT
                     , @c_RFIDNo1   OUTPUT
                     , @n_SeqNo2    OUTPUT
                     , @c_TidNo2    OUTPUT
                     , @c_RFIDNo2   OUTPUT
                     , @n_SeqNo3    OUTPUT
                  , @c_TidNo3    OUTPUT
                  , @c_RFIDNo3   OUTPUT
                  , @n_SeqNo4    OUTPUT
                  , @c_TidNo4    OUTPUT
                  , @c_RFIDNo4   OUTPUT
                  , @n_SeqNo5    OUTPUT
                  , @c_TidNo5    OUTPUT
                  , @c_RFIDNo5   OUTPUT                
   END
    
QUIT_SP:

END -- procedure

GO