SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Stored Procedure: isp_Insert_Allocate_Candidates                     */    
/* Creation Date: 2020-04-08                                            */    
/* Copyright: LF                                                        */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose: Dynamic SQL review, impact SQL cache log                    */
/*                                                                      */
/*                                                                      */    
/* Called By:                                                           */    
/*                                                                      */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 1.0                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date        Author   Ver.  Purposes                                  */    
/* 11-Jan-2023 NJOW01   1.0   WMS-19078 Increate othervalue size        */
/* 11-Jan-2023 NJOW01   1.0   DEVOPS Combine Script                     */
/************************************************************************/ 
CREATE   PROC [dbo].[isp_Insert_Allocate_Candidates]  
      @c_Lot            NVARCHAR(10)  
   ,  @c_Loc            NVARCHAR(10)  
   ,  @c_ID             NVARCHAR(18)  
   ,  @n_QtyAvailable   INT
   ,  @c_OtherValue     NVARCHAR(500) = '1' --NJOW01
   ,  @c_PickCode       NVARCHAR(30) = ''
   ,  @c_Storerkey      NVARCHAR(10) = ''
   ,  @c_Sku            NVARCHAR(20) = ''
AS  
BEGIN 
   SET NOCOUNT ON 

   INSERT INTO #ALLOCATE_CANDIDATES (Lot, Loc, Id, QtyAvailable, OtherValue)  
   VALUES ( @c_Lot, @c_Loc, @c_ID, @n_QtyAvailable, @c_OtherValue )  

   DECLARE @dt_date DATETIME = GETDATE()
   EXEC isp_InsertTraceInfo 
          @c_TraceCode ='INS_CAND_A', @c_TraceName ='isp_Insert_Allocate_Candidates'
         ,@c_starttime=@dt_date, @c_endtime=@dt_date
         ,@c_Step1=@c_Lot,@c_Step2=@c_PickCode,@c_Step3=@c_Storerkey,@c_Step4=@c_Sku, @c_Step5=''
         ,@c_Col1='',@c_Col2='',@c_Col3='',@c_Col4='',@c_Col5=''
         ,@b_Success=1,@n_Err=0,@c_ErrMsg=''
END

GO