SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_RFID_ExtractTags                                    */
/* Creation Date: 2020-10-05                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose:  WMS-14739 - CN NIKE O2 WMS RFID Receiving Module           */
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
/* 09-OCT-2020 Wan      1.0   Created                                   */
/************************************************************************/
CREATE PROC [dbo].[isp_RFID_ExtractTags]
           @c_TagData1           NVARCHAR(1000)
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

         , @n_RowNo           INT = 0
         , @n_GroupTag        INT = 0
         , @n_NoOfTagVal      INT = 4
         , @c_TagData         NVARCHAR(100) = ''


         , @CUR_RFID          CURSOR

   DECLARE @RFIDTag TABLE
      (  RowID                INT      IDENTITY(1,1) 
      ,  GroupTag             INT            DEFAULT (0)
      ,  TagData              NVARCHAR(100)  DEFAULT (0) 
      )

   IF @c_TagData1 <> ''
   BEGIN
      INSERT INTO @RFIDTag 
         (  GroupTag
         ,  TagData
         )
      SELECT 1
         ,   [Value]
       FROM string_split(@c_TagData1, '|')
   END
   
   IF @c_TagData2 <> ''
   BEGIN
      INSERT INTO @RFIDTag 
         (  GroupTag
         ,  TagData
         )
      SELECT 2
         ,   [Value]
      FROM string_split(@c_TagData2, '|')
   END

   IF @c_TagData3 <> ''
   BEGIN
      INSERT INTO @RFIDTag 
         (  GroupTag
         ,  TagData
         )
      SELECT 3
         ,   [Value]
      FROM string_split(@c_TagData3, '|')
   END

   IF @c_TagData4 <> ''
   BEGIN
      INSERT INTO @RFIDTag 
         (  GroupTag
         ,  TagData
         )
      SELECT 4
         ,   [Value]
      FROM string_split(@c_TagData4, '|')
   END

   IF @c_TagData5 <> ''
   BEGIN
      INSERT INTO @RFIDTag 
         (  GroupTag
         ,  TagData
         )
      SELECT 5
         ,   [Value]
      FROM string_split(@c_TagData5, '|')
   END
  
   SET @CUR_RFID = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT RowNo = ROW_NUMBER() OVER (PARTITION BY GroupTag ORDER BY RowID)
         ,GroupTag
         ,TagData  
   FROM   @RFIDTag
   ORDER BY GroupTag

   
   OPEN @CUR_RFID
   
   FETCH NEXT FROM @CUR_RFID INTO @n_RowNo, @n_GroupTag, @c_TagData
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF @n_GroupTag = 1
      BEGIN
         IF @n_RowNo % @n_NoOfTagVal = 1
            SET @n_SeqNo1  = @c_TagData
         IF @n_RowNo % @n_NoOfTagVal = 2
            SET @c_TidNo1  = @c_TagData
         IF @n_RowNo % @n_NoOfTagVal = 3
            SET @c_RFIDNo1 = @c_TagData
      END
      
      IF @n_GroupTag = 2
      BEGIN
         IF @n_RowNo % @n_NoOfTagVal = 1
            SET @n_SeqNo2  = @c_TagData
         IF @n_RowNo % @n_NoOfTagVal = 2
            SET @c_TidNo2  = @c_TagData
         IF @n_RowNo % @n_NoOfTagVal = 3
            SET @c_RFIDNo2 = @c_TagData
      END

      IF @n_GroupTag = 3
      BEGIN
         IF @n_RowNo % @n_NoOfTagVal = 1
            SET @n_SeqNo3  = @c_TagData
         IF @n_RowNo % @n_NoOfTagVal = 2
            SET @c_TidNo3  = @c_TagData
         IF @n_RowNo % @n_NoOfTagVal = 3
            SET @c_RFIDNo3 = @c_TagData
      END

      IF @n_GroupTag = 4
      BEGIN
         IF @n_RowNo % @n_NoOfTagVal = 1
            SET @n_SeqNo4  = @c_TagData
         IF @n_RowNo % @n_NoOfTagVal = 2
            SET @c_TidNo4  = @c_TagData
         IF @n_RowNo % @n_NoOfTagVal = 3
            SET @c_RFIDNo4 = @c_TagData
      END

      IF @n_GroupTag = 5
      BEGIN
         IF @n_RowNo % @n_NoOfTagVal = 1
            SET @n_SeqNo5  = @c_TagData
         IF @n_RowNo % @n_NoOfTagVal = 2
            SET @c_TidNo5  = @c_TagData
         IF @n_RowNo % @n_NoOfTagVal = 3
            SET @c_RFIDNo5 = @c_TagData
      END

      FETCH NEXT FROM @CUR_RFID INTO @n_RowNo, @n_GroupTag, @c_TagData
   END

   CLOSE @CUR_RFID
   DEALLOCATE @CUR_RFID  
QUIT_SP:

END -- procedure

GO