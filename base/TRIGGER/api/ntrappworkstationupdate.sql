SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ntrAppWorkstationUpdate                                     */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author      Purposes                                     */
/* 05-05-2020  Chermaine   Review Editdate column update                */
/* 18-08-2021  Wan01       HouseKeep & Log record to AppWorkStation_Log */
/************************************************************************/
CREATE TRIGGER [API].[ntrAppWorkstationUpdate] ON [API].[AppWorkstation] 
FOR UPDATE
AS
BEGIN
   IF @@ROWCOUNT = 0
   BEGIN
      RETURN
   END   
   SET NOCOUNT ON
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @n_continue INT       = 1                     --(Wan01)
         , @b_success  int       -- Populated by calls to stored procedures - was the proc successful?
         , @n_err      int       -- Error number returned by stored procedure or this trigger  
         , @c_errmsg   NVARCHAR(250) -- Error message returned by stored procedure or this trigger 

   DECLARE  @c_AppName NVARCHAR(30) = ''                 --(Wan01)
         ,  @c_CurrentVersion  NVARCHAR(12)   = ''       --(Wan01)
   

   IF NOT UPDATE(EditDate)
   BEGIN
      UPDATE API.AppWorkstation
      SET EditDate = GETDATE(),
          EditWho = SUSER_SNAME()
      FROM API.AppWorkstation (NOLOCK),   INSERTED
     WHERE AppWorkstation.Workstation = INSERTED.Workstation
   END
   
   --(Wan01) - START
   IF UPDATE(CurrentVersion) 
   BEGIN
      WHILE 1 = 1 AND @n_Continue = 1
      BEGIN
         SELECT @c_AppName = i.AppName
         FROM INSERTED i 
         JOIN DELETED d ON d.APPName = i.APPName AND d.Workstation = i.Workstation AND d.DeviceID = i.DeviceID
         WHERE i.AppName > @c_AppName
         AND i.CurrentVersion <> d.CurrentVersion
         GROUP BY i.AppName
         ORDER BY i.AppName
      
         IF @@ROWCOUNT = 0 
         BEGIN
            BREAK
         END

         INSERT INTO api.AppWorkStation_Log ( AppName, Workstation, DeviceID, CurrentVersion, TargetVersion )
         SELECT  i.AppName, i.Workstation, i.DeviceID, i.CurrentVersion, i.TargetVersion
         FROM INSERTED i 
         WHERE i.AppName = @c_AppName   
      
         IF @@ERROR <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_err = 80100
            SET @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err)
                          + ': Error Insert Into api.AppWorkStation_Log. (ntrAppWorkstationUpdate)'
         END
         
         IF @n_continue = 1
         BEGIN
            WHILE 1 = 1 AND @n_continue = 1
            BEGIN 
               IF NOT EXISTS (SELECT 1 FROM api.AppWorkStation_Log  awsl WITH (NOLOCK)
                              WHERE awsl.APPName = @c_AppName 
                              HAVING COUNT(DISTINCT CurrentVersion) > 5
                         )
               BEGIN
                  BREAK
               END
                
               SELECT TOP 1 @c_CurrentVersion = awsl.CurrentVersion
               FROM api.AppWorkStation_Log  awsl WITH (NOLOCK)
               WHERE awsl.APPName = @c_AppName
               ORDER BY awsl.AddDate
      
               ; WITH del (AppWorkStationLogKey) AS
               (  SELECT awsl.AppWorkStationLogKey
                  FROM api.AppWorkStation_Log  awsl WITH (NOLOCK)
                  WHERE awsl.APPName = @c_AppName
                  AND awsl.CurrentVersion = @c_CurrentVersion
               )
      
               DELETE awsl WITH (ROWLOCK)
               FROM api.AppWorkstation_Log awsl
               JOIN del ON del.AppWorkStationLogKey = awsl.AppWorkStationLogKey
            
               IF @@ERROR <> 0
               BEGIN
                  SET @n_continue = 3
                  SET @n_err = 80200
                  SET @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err)
                                + ': Error Delete(s) record from api.AppWorkStation_Log'
                                + '. (ntrAppWorkstationUpdate)'
               END
             END
         END
      END  
   END    
   /* Return Statement */  
END

GO