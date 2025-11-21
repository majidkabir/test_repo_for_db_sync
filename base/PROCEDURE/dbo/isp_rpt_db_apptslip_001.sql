SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/    
/* Stored Procedure: isp_RPT_DB_APPTSLIP_001                               */    
/* Creation Date: 28-MARCH-2022                                            */    
/* Copyright: LFL                                                          */    
/* Written by: WZPang                                                      */    
/*                                                                         */    
/* Purpose: WMS-18972 - PH Unilever Appointment Number Report              */    
/*                                                                         */    
/* Called By: RPT_DB_APPTSLIP_001                                          */    
/*                                                                         */    
/* GitLab Version: 1.0                                                     */    
/*                                                                         */    
/* Version: 1.0                                                            */    
/*                                                                         */    
/* Data Modifications:                                                     */    
/*                                                                         */    
/* Updates:                                                                */    
/* Date         Author  Ver   Purposes                                     */
/* 30-Mar-2022  WLChooi 1.0   DevOps Combine Script                        */  
/***************************************************************************/        
CREATE PROC [dbo].[isp_RPT_DB_APPTSLIP_001] (
      @n_BookingNo   INT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET ANSI_DEFAULTS OFF

   SELECT DISTINCT BO.BookingNo,
                   TS.ShipmentGID
   FROM Booking_Out BO (NOLOCK)
   JOIN TMS_Shipment TS ON ( TS.BookingNo = BO.BookingNo )
   WHERE BO.BookingNo = @n_BookingNo
END

GO