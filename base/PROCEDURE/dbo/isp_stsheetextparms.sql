SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: isp_STSheetExtParms                                         */
/* Creation Date: 28-MAR-2016                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose:  StockTakeSheet Extended Parameters                         */
/*        :                                                             */
/* Called By:  d_dddw_STSheetextparm                                    */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_STSheetExtParms] 
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 

   SET @n_StartTCnt = @@TRANCOUNT

   SELECT '' COLUMN_NAME
         ,'' DATA_TYPE
   UNION
   SELECT TABLE_NAME + '.' + COLUMN_NAME, DATA_TYPE
   FROM [INFORMATION_SCHEMA].COLUMNS
   WHERE TABLE_NAME  IN ( 'SKU', 'LOC', 'LOTATTRIBUTE' )
   AND COLUMN_NAME NOT IN ('TrafficCop', 'ArchiveCop', 'AddWho', 'EditWho')
   AND DATA_TYPE NOT IN ( 'datetime', 'image' ) 

QUIT:
END -- procedure

GO