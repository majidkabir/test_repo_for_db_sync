SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* View: dbo.V_APTSTRGROUP_Columns                                      */
/* Creation Date: 2022-11-25                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: LFWM-3866 - Codelkup for door booking strategy config       */
/*        :                                                             */
/* Called By: SCE UI DropDown                                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 8.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2022-11-25  Wan      1.0   Created & DevOps Combine Script           */
/************************************************************************/
CREATE   VIEW [dbo].[V_APTSTRGROUP_Columns] AS
SELECT  FieldName= UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME)
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('TMS_SHIPMENT')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'EditWho', 'RowRef', 'AppointmentID','BookingNo')

GO