SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_BuildParmGroupCfg_Validation                        */
/* Creation Date: 11-APR-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-4533 - Mercury RG - Upgrade filtering Criteri (UI)      */
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
/************************************************************************/
CREATE PROC [dbo].[isp_BuildParmGroupCfg_Validation]
           @c_Storerkey    NVARCHAR(15)
         , @c_Facility     NVARCHAR(5)
         , @c_Type         NVARCHAR(30)
         , @c_ParmGroup    NVARCHAR(30)   OUTPUT
         , @c_ColumnName   NVARCHAR(60) 
         , @b_Success      INT            OUTPUT
         , @n_Err          INT            OUTPUT
         , @c_ErrMsg       NVARCHAR(255)  OUTPUT
         , @n_WarningNo    INT   = 0      OUTPUT
         , @c_ProceedWithWarning CHAR(1) = 'N'
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 

         , @n_Count           INT
         , @n_ParmGroupCfgID  BIGINT

         , @c_PGRP_Storerkey  NVARCHAR(15)
         , @c_PGRP_Type       NVARCHAR(30)
         , @c_PGRP_ParmGroup  NVARCHAR(30)
         , @c_Description     NVARCHAR(60)


   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   BEGIN TRAN

   IF @c_ColumnName = 'StorerkeyBuild'
   BEGIN
      IF NOT EXISTS (SELECT 1
                     FROM STORER WITH (NOLOCK)
                     WHERE Storerkey = @c_Storerkey
                    )
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 63010
         SET @c_ErrMsg = 'NSQL:' + CONVERT(CHAR(5), @n_Err) + ': Invalid Storerkey: ' + RTRIM(@c_Storerkey)
                       + '. isp_BuildParmGroupCfg_Validation'
         GOTO QUIT_SP
      END

      GOTO QUIT_SP
   END
   
   IF @c_ColumnName = 'FacilityBuild'
   BEGIN
      IF NOT EXISTS (SELECT 1
                     FROM FACILITY WITH (NOLOCK)
                     WHERE Facility = @c_Facility
                    )
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 63020
         SET @c_ErrMsg = 'NSQL:' + CONVERT(CHAR(5), @n_Err) + ': Invalid Facility: ' + RTRIM(@c_Facility)
                       + '. isp_BuildParmGroupCfg_Validation'
         GOTO QUIT_SP
      END

      GOTO QUIT_SP
   END

   IF @c_ColumnName = 'Type'
   BEGIN
      SET @c_ParmGroup = ''
      SELECT @c_ParmGroup = ParmGroup
      FROM BUILDPARMGROUPCFG WITH (NOLOCK) 
      WHERE StorerKey = @c_StorerKey 
      AND   Facility = CASE WHEN RTRIM(@c_Facility) <> '' THEN RTRIM(@c_Facility) ELSE Facility END
      AND   Type = @c_Type

      GOTO QUIT_SP
   END
   
   IF @c_ColumnName = 'ParmGroup'
   BEGIN
      IF ISNULL(RTRIM(@c_ParmGroup),'') = ''
      BEGIN
         GOTO QUIT_SP
      END

      IF @c_ProceedWithWarning = 'N' AND @n_WarningNo = 0
      BEGIN 
         SET @n_Count = 0
         SELECT TOP 1 
               @n_Count = 1
            ,  @c_PGRP_Storerkey = Storerkey
            ,  @c_PGRP_Type      = Type
         FROM BUILDPARMGROUPCFG WITH (NOLOCK) 
         WHERE ParmGroup = @c_ParmGroup 

         IF @n_Count = 1
         BEGIN
            IF @c_Storerkey <> @c_PGRP_Storerkey
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 63030
               SET @c_ErrMsg = 'NSQL:' + CONVERT(CHAR(5), @n_Err) + ': This Parameter Group is used by Storer: ' + RTRIM(@c_PGRP_Storerkey)
                              + '. isp_BuildParmGroupCfg_Validation'
               GOTO QUIT_SP
            END

            IF @c_Type <> @c_PGRP_Type
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 63040
               SET @c_ErrMsg = 'NSQL:' + CONVERT(CHAR(5), @n_Err) + ': This Parameter Group is used by Type: ' + RTRIM(@c_PGRP_Type)
                              + '. isp_BuildParmGroupCfg_Validation'
               GOTO QUIT_SP
            END
         END

         SET @n_Count = 0
         SELECT @n_Count = 1
               ,@c_PGRP_ParmGroup = ISNULL(RTRIM(ParmGroup),'')
         FROM BUILDPARMGROUPCFG WITH (NOLOCK) 
         WHERE StorerKey = @c_StorerKey 
         AND   Facility = CASE WHEN RTRIM(@c_Facility) <> '' THEN RTRIM(@c_Facility) ELSE Facility END
         AND   Type = @c_type 

         IF @n_Count = 0
         BEGIN
            IF @n_WarningNo < 1
            BEGIN
               SET @n_Continue = 3
               SET @c_ErrMsg = 'Do you want to Add New Parameter Group?'
               SET @n_WarningNo = 1
            END

            GOTO QUIT_SP
         END

         IF @c_ParmGroup <> @c_PGRP_ParmGroup
         BEGIN
            -- Check Original ParmGroup is setup in other facility
            SET @n_Count = 0
            SELECT @n_Count = COUNT(DISTINCT Facility)
            FROM BUILDPARMGROUPCFG WITH (NOLOCK) 
            WHERE StorerKey = @c_StorerKey 
            AND   Type = @c_type             
            AND   ParmGroup = @c_PGRP_ParmGroup

            IF @n_Count = 1
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 63050
               SET @c_ErrMsg = 'NSQL:' + CONVERT(CHAR(5), @n_Err) + ': Parameter Group already setup, Cannot Change'
                              + '. isp_BuildParmGroupCfg_Validation'
               GOTO QUIT_SP
            END

            IF @n_WarningNo < 2
            BEGIN
               SET @n_Continue = 3
               SET @c_ErrMsg = 'Do you want to Change Parameter Group?'
               SET @n_WarningNo = 2
            END

            GOTO QUIT_SP
         END
      END

      IF @c_ProceedWithWarning = 'Y' AND @n_WarningNo = 1
      BEGIN
         SET @c_Description = ''
         SELECT @c_Description = ISNULL(RTRIM(CL.Description),'')
         FROM CODELKUP CL WITH (NOLOCK)
         WHERE CL.ListName = 'BLDPARMTYP'
         AND   CL.Code = @c_Type

         INSERT INTO BUILDPARMGROUPCFG
            ( Storerkey, Facility, Description, Type, ParmGroup )
         VALUES (@c_Storerkey, @c_Facility, @c_Description, @c_Type, @c_ParmGroup)

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 63060
            SET @c_ErrMsg = 'NSQL:' + CONVERT(CHAR(5), @n_Err) + ': Insert Into BUILDPARMGROUPCFG fail'
                          + '. isp_BuildParmGroupCfg_Validation'
            GOTO QUIT_SP
         END
   
         GOTO QUIT_SP
      END 

      IF @c_ProceedWithWarning = 'Y' AND @n_WarningNo = 2
      BEGIN
         SET @n_ParmGroupCfgID = 0
         SELECT TOP 1 @n_ParmGroupCfgID = ParmGroupCfgID
         FROM BUILDPARMGROUPCFG WITH (NOLOCK)
         WHERE Storerkey = @c_Storerkey      
         AND   Facility  = @c_Facility 
         AND   Type      = @c_Type

         IF @n_ParmGroupCfgID = 0
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 63070
            SET @c_ErrMsg = 'NSQL:' + CONVERT(CHAR(5), @n_Err) + ': Record not found for BUILDPARMGROUPCFG table update.'
                          + '. isp_BuildParmGroupCfg_Validation'
            GOTO QUIT_SP
         END

         UPDATE BUILDPARMGROUPCFG WITH (ROWLOCK)
            SET ParmGroup = @c_ParmGroup 
               ,EditWho = SUSER_NAME()
               ,EditDate= GETDATE()
               ,TrafficCop = NULL
         WHERE ParmGroupCfgID = @n_ParmGroupCfgID

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 63080
            SET @c_ErrMsg = 'NSQL:' + CONVERT(CHAR(5), @n_Err) + ': Update BUILDPARMGROUPCFG fail'
                          + '. isp_BuildParmGroupCfg_Validation'
            GOTO QUIT_SP
         END
   
         GOTO QUIT_SP
      END 
   END

QUIT_SP:

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_BuildParmGroupCfg_Validation'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END

      SET @n_WarningNo = 0
   END
END -- procedure

GO