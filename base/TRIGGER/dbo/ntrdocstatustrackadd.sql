SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ntrDocStatusTrackAdd                                        */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/* Version: 5.5                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 28-Jul-2016  MCTang 1.0    Add ITFTriggerConfig for MBOL (MC01)      */
/* 11-Jul_2017  MCTang 1.1    Enhance Generaic Trigger Interface (MC02) */
/* 18-May_2020  TLTING 1.2    ANSI NULL                                 */
/************************************************************************/

CREATE TRIGGER [dbo].[ntrDocStatusTrackAdd]
ON  [dbo].[DocStatusTrack]
FOR INSERT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Success            INT            -- Populated by calls to stored procedures - was the proc successful?
         , @n_Err                INT            -- Error number returned by stored procedure or this trigger
         , @c_ErrMsg             NVARCHAR(250)  -- Error message returned by stored procedure or this trigger
         , @n_Continue           INT
         , @n_starttcnt          INT            -- Holds the current transaction count

   DECLARE @c_StorerKey          NVARCHAR(15) 
         , @c_TriggerName        NVARCHAR(120)
         , @c_SourceTable        NVARCHAR(60)
         , @n_RowRef             INT
         , @c_DocumentNo         NVARCHAR(20)   --(MC02)
         , @c_TableName          NVARCHAR(30)   --(MC02)   
         , @c_Proceed            CHAR(1)        --(MC02)

   SELECT @n_Continue=1, @n_starttcnt=@@TRANCOUNT

   SET @c_DocumentNo = ''   --(MC02)
   SET @c_TableName  = ''   --(MC02)  
   SET @c_Proceed    = 'N'  --(MC02)  

   SET @c_TriggerName = 'ntrDocStatusTrackAdd'
   SET @c_SourceTable = 'DocStatusTrack'

   IF EXISTS( SELECT 1 FROM INSERTED WHERE ArchiveCop = '9')
   BEGIN
      SELECT @n_Continue = 4
   END

   /* #INCLUDE <TRLU1.SQL> */

   DECLARE @b_ColumnsUpdated VARBINARY(1000)       
   SET @b_ColumnsUpdated = COLUMNS_UPDATED()      

   IF @n_Continue = 1 or @n_Continue = 2
   BEGIN

      --(MC02) - S
      /*
      DECLARE Cur_Itf_TriggerPoints CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT  INS.RowRef 
            , INS.Storerkey 
      FROM    INSERTED INS 
      JOIN  ITFTriggerConfig ITC WITH (NOLOCK) ON ITC.StorerKey = INS.StorerKey  
      WHERE ITC.SourceTable = 'DocStatusTrack'  
      AND   ITC.sValue      = '1' 
      AND   INS.TableName   <> 'MBOL'                --(MC01)

      OPEN Cur_Itf_TriggerPoints
      FETCH NEXT FROM Cur_Itf_TriggerPoints INTO @n_RowRef, @c_StorerKey

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         -- Execute SP - isp_ITF_ntrDocStatusTrack
         EXECUTE dbo.isp_ITF_ntrDocStatusTrack 
                  @c_TriggerName
                , @c_SourceTable
                , @c_StorerKey
                , @n_RowRef
                , @b_ColumnsUpdated
                , @b_Success  OUTPUT
                , @n_Err      OUTPUT
                , @c_ErrMsg   OUTPUT

         FETCH NEXT FROM Cur_Itf_TriggerPoints INTO @n_RowRef, @c_StorerKey
      END -- WHILE @@FETCH_STATUS <> -1
      CLOSE Cur_Itf_TriggerPoints
      DEALLOCATE Cur_Itf_TriggerPoints

      --(MC01) - S
      DECLARE Cur_Itf_TriggerPoints CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT DISTINCT INS.RowRef 
                    , OH.Storerkey 
      FROM  INSERTED INS 
      JOIN  MbolDetail MD WITH (NOLOCK) ON INS.DocumentNo = MD.MbolKey
      JOIN  Orders OH WITH (NOLOCK) ON MD.OrderKey = OH.OrderKey   
      JOIN  ITFTriggerConfig ITC WITH (NOLOCK) ON ITC.StorerKey = OH.StorerKey  
      WHERE ITC.SourceTable = 'DocStatusTrack'  
      AND   ITC.sValue      = '1' 
      AND   INS.TableName   = 'MBOL'               

      OPEN Cur_Itf_TriggerPoints
      FETCH NEXT FROM Cur_Itf_TriggerPoints INTO @n_RowRef, @c_StorerKey

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         -- Execute SP - isp_ITF_ntrDocStatusTrack
         EXECUTE dbo.isp_ITF_ntrDocStatusTrack 
                  @c_TriggerName
                , @c_SourceTable
                , @c_StorerKey
                , @n_RowRef
                , @b_ColumnsUpdated
                , @b_Success  OUTPUT
                , @n_Err      OUTPUT
                , @c_ErrMsg   OUTPUT

         FETCH NEXT FROM Cur_Itf_TriggerPoints INTO @n_RowRef, @c_StorerKey
      END -- WHILE @@FETCH_STATUS <> -1
      CLOSE Cur_Itf_TriggerPoints
      DEALLOCATE Cur_Itf_TriggerPoints
      --(MC01) - E
      */

      DECLARE Cur_TriggerPoints2 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
      SELECT DISTINCT INS.RowRef, INS.StorerKey, INS.DocumentNo, INS.TableName
      FROM   INSERTED INS             

      OPEN Cur_TriggerPoints2  
      FETCH NEXT FROM Cur_TriggerPoints2 INTO @n_RowRef, @c_StorerKey, @c_DocumentNo, @c_TableName

      WHILE @@FETCH_STATUS <> -1  
      BEGIN

         -- IF 'MBOL' >> DocStatusTrack.Storerkey = ''
         IF @c_TableName = 'MBOL' 
         BEGIN
            SELECT @c_Storerkey = OH.Storerkey 
            FROM   MbolDetail MD WITH (NOLOCK) 
            JOIN   Orders OH WITH (NOLOCK) ON MD.OrderKey = OH.OrderKey 
            WHERE  MD.MbolKey = @c_DocumentNo
         END

         SET @c_Proceed = 'N'

         IF EXISTS(SELECT 1 
   	             FROM  ITFTriggerConfig ITC WITH (NOLOCK)       
   	             WHERE ITC.StorerKey   = @c_Storerkey
   	             AND   ITC.SourceTable = 'DocStatusTrack'  
                   AND   ITC.sValue      = '1' )
         BEGIN
            SET @c_Proceed = 'Y'           
         END

         -- For OTMLOG StorerKey = 'ALL'
   	   IF EXISTS(SELECT 1 
   	             FROM  StorerConfig STC WITH (NOLOCK)        
   	             WHERE STC.StorerKey = @c_Storerkey 
   	             AND   STC.SValue    = '1' 
   	             AND   EXISTS(SELECT 1 
                                FROM  ITFTriggerConfig ITC WITH (NOLOCK)
   	                          WHERE ITC.StorerKey   = 'ALL' 
   	                          AND   ITC.SourceTable = 'DocStatusTrack'  
                                AND   ITC.sValue      = '1' 
                                AND   ITC.ConfigKey = STC.ConfigKey ))
         BEGIN                  
            SET @c_Proceed = 'Y'                          	
         END       

         IF @c_Proceed = 'Y'
         BEGIN
            EXECUTE dbo.isp_ITF_ntrDocStatusTrack 
                     @c_TriggerName
                   , @c_SourceTable
                   , @c_StorerKey
                   , @n_RowRef
                   , @b_ColumnsUpdated
                   , @b_Success  OUTPUT
                   , @n_Err      OUTPUT
                   , @c_ErrMsg   OUTPUT 
         END

         FETCH NEXT FROM Cur_TriggerPoints2 INTO @n_RowRef, @c_StorerKey, @c_DocumentNo, @c_TableName
      END -- WHILE @@FETCH_STATUS <> -1  
      CLOSE Cur_TriggerPoints2  
      DEALLOCATE Cur_TriggerPoints2 
      --(MC02) - E
   END

   /* #INCLUDE <TRLU2.SQL> */

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      IF @@TRANCOUNT = 1 and @@TRANCOUNT >= @n_starttcnt
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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ntrDocStatusTrackAdd'
      RAISERROR (@c_ErrMsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO