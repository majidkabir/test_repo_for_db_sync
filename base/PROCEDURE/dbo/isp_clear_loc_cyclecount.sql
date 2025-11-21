SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/***************************************************************************/
/* Stored Procedure: isp_Clear_LOC_CycleCount                              */
/* Creation Date:                                                          */
/* Copyright: IDS                                                          */
/* Written by: JayLim                                                      */
/*                                                                         */
/* Purpose:                                                                */
/*                                                                         */
/* Called By: Job-   BEJ - CC LOC CycleCounter                             */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author     Ver   Purposes                                  */
/* 21-July-2016  JayLim    1.1   Script Revise (Jay01)                     */
/***************************************************************************/

CREATE PROC [dbo].[isp_Clear_LOC_CycleCount]
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET ANSI_WARNINGS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @b_debug  INT,
           @n_err    INT,
           @c_errmsg NVARCHAR(255),
           @n_continue 		  int,
           @b_Success	     int,
           @n_starttcnt		  int

   DECLARE @c_UDF01  NVARCHAR(10),
           @c_Code   NVARCHAR(10),
           @c_Loc    NVARCHAR(10),
           @c_ZoneCode  NVARCHAR(10)


   SELECT @n_starttcnt = @@TRANCOUNT 

   SELECT @b_debug = 0
   SELECT @b_Success = 0
   SELECT @n_continue = 1

   SELECT @c_UDF01 = ''
   SELECT @c_Code = ''
   SELECT @c_ZoneCode = ''
   SELECT @c_Loc = ''

   -- 1st CURSOR DECLARE
   DECLARE READ_CODELKUP_UDF01  CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT ISNULL(NULLIF(UDF01, ''),'BLANK'), ISNULL(NULLIF(Code,''),'BLANK')
   FROM CODELKUP WITH (NOLOCK)
   WHERE Listname = 'CYCLEINFO'

   SELECT @n_err = @@ERROR

   OPEN READ_CODELKUP_UDF01

   FETCH NEXT FROM READ_CODELKUP_UDF01 INTO @c_UDF01, @c_Code

   IF (@c_UDF01 <> 'BLANK' AND @c_Code <> 'BLANK')
      BEGIN 
         SELECT @n_continue = 1
      END
   ELSE
      BEGIN
         SELECT @n_continue = 2
      END

   IF(@n_continue = 1)
   BEGIN
      WHILE @@FETCH_STATUS <> -1   --1st Cursor fetch_status     
      BEGIN -- 1st cursor loop start
         IF (CONVERT(VARCHAR(12), GETDATE(), 112) = @c_UDF01)
            BEGIN
               IF @b_debug = 1
                  BEGIN
                     SELECT 'Selecting From CODELKUP '
                     SELECT 'Code ', @c_Code
                     SELECT 'UDF01 ', @c_UDF01
                  END
               -- 2nd CURSOR DECLARE
               DECLARE READ_CODELKUP_LONG CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 

               SELECT ISNULL(NULLIF(RIGHT(LEFT(T.Long,Number-1),CHARINDEX(',',REVERSE(LEFT(','+T.Long,Number-1)))),''),'BLANK')
               FROM
                  master..spt_values,
                  CODELKUP T WITH (NOLOCK)
               WHERE Type = 'P' 
                     AND Number BETWEEN 1 AND LEN(T.Long)+1
                     AND (SUBSTRING(T.Long,Number,1) = ',' OR SUBSTRING(T.Long,Number,1)  = '') 
                     AND T.Code = @c_Code
                     AND T.Long IS NOT NULL
                     AND NULLIF(T.Long,'') IS NOT NULL

               OPEN READ_CODELKUP_LONG

               FETCH NEXT FROM READ_CODELKUP_LONG INTO @c_ZoneCode

               IF (@c_ZoneCode <> 'BLANK')
                  BEGIN 
                     SELECT @n_continue = 1
                  END
               ELSE
                  BEGIN
                     SELECT @n_continue = 2
                  END

               IF(@n_continue = 1)
               BEGIN
                  WHILE @@FETCH_STATUS <> -1     --2nd Cursor fetch_status   
                     BEGIN -- 2nd cursor loop start
                        IF @b_debug = 1
                        BEGIN
                           SELECT 'Selecting From CODELKUP.LONG '
                           SELECT 'Long ', @c_ZoneCode
                        END

                        -- 3rd Cursor DECLARE
                        DECLARE READ_LOC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                        SELECT ISNULL(NULLIF(Loc,''),'BLANK')
                        FROM LOC WITH (NOLOCK)
                        WHERE PutawayZone = @c_ZoneCode  -- Jay01
                       
                        OPEN READ_LOC
            
                        FETCH NEXT FROM READ_LOC INTO @c_Loc

                        IF (@c_Loc <> 'BLANK')
                           BEGIN
                              SELECT @n_continue = 1
                           END
                        ELSE
                           BEGIN
                              SELECT @n_continue = 2
                           END

                        IF(@n_continue = 1)
                        BEGIN
                           WHILE @@FETCH_STATUS <> -1 --3rd Cursor fetch_status
                               BEGIN -- 3rd cursor loop start
                                 IF @b_debug = 1
                                    BEGIN
                                       SELECT 'Updating CycleCounter From LOC '
                                       SELECT 'Loc ', @c_Loc
                                    END

                                 BEGIN TRAN

                                 UPDATE LOC WITH (ROWLOCK) --(Jay01)
                                 SET CycleCounter = 0
                                 WHERE Loc = @c_Loc

                                 IF @@ERROR = 0
                                    BEGIN 
                                       COMMIT TRAN
                                    END
                                 ELSE
                                    BEGIN
                                       ROLLBACK TRAN
                                       SELECT @n_continue = 3
                                       SELECT @n_err = 65002
                                       SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err) + ': Update records failed (isp_Clear_LOC_CycleCount)'  
                                    END
                                 FETCH NEXT FROM READ_LOC INTO @c_Loc
                              END -- 3rd cursor loop END
                           CLOSE READ_LOC
                           DEALLOCATE READ_LOC
                        END -- 3rd END of (@n_continue = 1)
                        FETCH NEXT FROM READ_CODELKUP_LONG INTO @c_ZoneCode
                     END-- 2nd cursor loop END
                  CLOSE READ_CODELKUP_LONG
                  DEALLOCATE READ_CODELKUP_LONG
               END -- 2nd END of (@n_continue = 1)
            END -- END for IF (CONVERT(VARCHAR(12), GETDATE(), 112) = @c_UDF01)
         FETCH NEXT FROM READ_CODELKUP_UDF01 INTO @c_UDF01, @c_Code
      END --1st crusor loop END
   END -- 1st END of (@n_continue = 1)
CLOSE READ_CODELKUP_UDF01
DEALLOCATE READ_CODELKUP_UDF01

-- Raise Error if @n_err <> 0
   IF @n_continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SELECT @b_success = 0  
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt  
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

      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_Clear_LOC_CycleCount'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE  
   BEGIN  
      SELECT @b_success = 1  
      WHILE @@TRANCOUNT > @n_starttcnt  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN  
   END
END

GO