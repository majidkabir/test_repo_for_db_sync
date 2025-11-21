SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Stored Procedure: isp_Insert_Preallocate_Candidates                  */    
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
/************************************************************************/ 
CREATE PROC [dbo].[isp_Insert_Preallocate_Candidates]  
      @c_Storerkey      NVARCHAR(15) 
   ,  @c_Sku            NVARCHAR(20) 
   ,  @c_Lot            NVARCHAR(10) 
   ,  @n_QtyAvailable   INT
   ,  @c_PickCode       NVARCHAR(30) = ''
AS  
BEGIN 
   SET NOCOUNT ON 

   INSERT INTO #PREALLOCATE_CANDIDATES (Storerkey, Sku, Lot, QtyAvailable)
   VALUES ( @c_Storerkey, @c_Sku, @c_Lot, @n_QtyAvailable ) 
   
   DECLARE @dt_date DATETIME = GETDATE()
   EXEC isp_InsertTraceInfo 
       @c_TraceCode ='INS_CAND_P', @c_TraceName ='isp_Insert_PreAllocate_Candidates'
      ,@c_starttime=@dt_date, @c_endtime=@dt_date
      ,@c_Step1=@c_Lot,@c_Step2=@c_PickCode,@c_Step3=@c_Storerkey,@c_Step4=@c_Sku, @c_Step5=''
      ,@c_Col1='',@c_Col2='',@c_Col3='',@c_Col4='',@c_Col5=''
      ,@b_Success=1,@n_Err=0,@c_ErrMsg=''   
END

GO