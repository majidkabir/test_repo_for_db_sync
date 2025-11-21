SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Procedure: isp_RDTPrintJob_JobStatusUpdate                    */
/* Creation Date: 2017-Jan-11                                           */
/* Copyright: IDS                                                       */
/* Written by: JayLim                                                   */
/*                                                                      */
/* Purpose: ò	Update rdt.rdtPrintJob.JobStatus from 0 to X,            */
/*             for those records not print within 1 hour                */
/*                                                                      */
/* Called By: BEJ - RDTPrintJob_JobStatus Update                        */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author      Ver.    Purposes                            */
/* 18-Jan-2017  JayLim     1.1      Script enhancement (Jay01)          */
/************************************************************************/

CREATE PROC [dbo].[isp_RDTPrintJob_JobStatusUpdate]
(
   @n_timediff_mins     INT,
   @b_debug             INT
)
AS 
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET ANSI_NULLS OFF

   DECLARE @Temp_RDTPrintJob_Table TABLE
   (
         JobID INT NOT NULL
   )

   DECLARE @n_continue INT
          ,@n_JobID    INT
          ,@n_timediff DATE


   IF (@n_timediff_mins = NULL OR @n_timediff_mins = '')
   BEGIN
      SET @n_timediff_mins = 60
      SET @n_timediff = DATEADD(MINUTE,(@n_timediff_mins * -1), GETDATE()) --(Jay01)
   END
   ELSE
   BEGIN
      SET @n_timediff = DATEADD(MINUTE,(@n_timediff_mins * -1), GETDATE()) --(Jay01)
   END


   IF ((@b_debug = NULL) OR (@b_debug = ''))
   BEGIN 
      SET @b_debug = 0
   END

   IF EXISTS (SELECT 1 FROM RDT.RDTPrintJob WITH (NOLOCK) 
              WHERE AddDate < @n_timediff             --(Jay01)
              AND JobStatus = '0')
   BEGIN     
      SET @n_continue = 1
   END
   ELSE
   BEGIN
      SET @n_continue = 3
   END

   IF (@n_continue = 1 OR @n_continue = 2)
   BEGIN
      
      INSERT INTO @Temp_RDTPrintJob_Table ([JobID])
      SELECT ISNULL(JobId,'') FROM RDT.RDTPrintJob WITH (NOLOCK) 
      WHERE AddDate < @n_timediff     --(Jay01)
      AND JobStatus = '0'

      IF (@b_debug = 1)
      BEGIN
         SELECT COUNT(1) AS 'Total record selected' FROM @Temp_RDTPrintJob_Table
         SELECT JobID AS 'selected jobid' FROM @Temp_RDTPrintJob_Table
      END

      IF NOT EXISTS ( SELECT 1 FROM @Temp_RDTPrintJob_Table)
      BEGIN 
         SET @n_continue = 3 -- no need to continue if no record inserted.
      END

   END

   IF (@n_continue = 1 OR @n_continue = 2)
   BEGIN 

      DECLARE READ_RDTPrintJob_Table CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT JobID FROM @Temp_RDTPrintJob_Table

      OPEN READ_RDTPrintJob_Table

      FETCH NEXT FROM READ_RDTPrintJob_Table INTO @n_JobID

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         
         UPDATE RDT.RDTPrintJob
         SET JobStatus = 'X'
         WHERE JobId = @n_JobID

         IF (@b_debug = 1)
         BEGIN
            PRINT  'Updated JobID :' +@n_JobID
         END

         FETCH NEXT FROM READ_RDTPrintJob_Table INTO @n_JobID
      END
      CLOSE READ_RDTPrintJob_Table
      DEALLOCATE  READ_RDTPrintJob_Table

   END
END

GO