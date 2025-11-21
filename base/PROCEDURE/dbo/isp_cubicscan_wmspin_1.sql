SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

      

/******************************************************************************/           
/* Copyright: IDS                                                             */           
/* Purpose: Cubic Scan WMSPIN 1 SP                                                */           
/*                                                                            */           
/* Modifications log:                                                         */           
/*                                                                            */           
/* Date       Rev  Author     Purposes                                        */           
/* 2016-08-15 1.0  Barnett    Created                                         */          
/******************************************************************************/          

CREATE PROC [dbo].[isp_CubicScan_WMSPIN_1] 
     @n_SerialNo INT          
    ,@b_Debug INT
	,@c_MessageType NVARCHAR(20)
    ,@b_Success INT OUTPUT           
    ,@n_Err INT OUTPUT           
    ,@c_ErrMsg NVARCHAR(250) OUTPUT               
AS          
BEGIN          
	SET NOCOUNT ON      
   

	IF EXISTS(SELECT 1 FROM TCPSocket_INLog ti (NOLOCK)  
				WHERE ti.SerialNo=@n_SerialNo   
				AND   ti.STATUS = '9')  
	BEGIN  
		RETURN   
	END       
                
	DECLARE @c_Status		NVARCHAR(1)  
		,@c_DataString		NVARCHAR(4000)  
		,@c_StorerKey		NVARCHAR(15)  
		,@c_MessageName		NVARCHAR(15)  
		,@n_StartTranCnt	INT 
		  
	DECLARE @Type			NVARCHAR(10),
			@DeviceID		NVARCHAR(10),
			@Referencekey	NVARCHAR(20),
			@Weight			Float,
			@Length			Float,
			@Width			Float,
			@Height			Float,
     		@Datetime		NVARCHAR(14),
			@c_Remarks      NVARCHAR(250),
			@LabelNo		NVARCHAR(20),
			@PickSlipNo		NVARCHAR(20),
			@CartonNo		INT
                   
	          
	SET @n_StartTranCnt = @@TRANCOUNT  
	SET @c_Status = '9'          

	SELECT @c_DataString = ti.[Data]          
	FROM TCPSocket_INLog ti WITH (NOLOCK)          
	WHERE ti.SerialNo = @n_SerialNo           
            
   
             
	DECLARE @c_Delim CHAR(1)   
	DECLARE @t_DPCRec TABLE (  
		Seqno    INT,   
		ColValue VARCHAR(215)  
		)  
     
	SET @c_Delim = '<TAB>'
  
	INSERT INTO @t_DPCRec  
	SELECT * FROM dbo.fnc_DelimSplit(@c_Delim, @c_DataString)     
	
	UPDATE @t_DPCRec
	SET ColValue = REPLACE ( ColValue, 'TAB>', '')
     

	SELECT @Type =ColValue   
	FROM @t_DPCRec  
	WHERE Seqno=2
	
	SELECT @DeviceID =ColValue   
	FROM @t_DPCRec  
	WHERE Seqno=3

	SELECT @Referencekey =ColValue   
	FROM @t_DPCRec  
	WHERE Seqno=4

	SELECT @Weight =ColValue   
	FROM @t_DPCRec  
	WHERE Seqno=5  

	SELECT @Length =ColValue   
	FROM @t_DPCRec  
	WHERE Seqno=6  

	SELECT @Width =ColValue   
	FROM @t_DPCRec  
	WHERE Seqno=7  

	SELECT @Height =ColValue   
	FROM @t_DPCRec  
	WHERE Seqno=8  

	SELECT @Datetime = ColValue   
	FROM @t_DPCRec  
	WHERE Seqno=9  


	IF @Referencekey<> ''
	BEGIN
			SELECT @c_StorerKey = Storerkey, @LabelNo = RefKey, @PickSlipNo = PickSlipNo, @CartonNo = CartonNo
			FROM(
					select distinct Storerkey, LabelNo 'RefKey', PickSlipNo, CartonNo from PackDetail (nolock) where LabelNo = @Referencekey
					union
					select distinct storerkey, LabelNo 'RefKey', PickSlipNo, CartonNo from PackDetail (nolock) where DropId = @Referencekey
				) a
	END
	
	

	       
                                            
	IF @b_Debug=1          
	BEGIN          
			select	@Type as 'Type',
					@DeviceID as 'DeviceID',
					@Referencekey as 'ReferenceKey',
					@Weight as 'Weight',
					@Length as 'Length',
					@Width as 'Width',
					@Height as 'Height',
					@Datetime as 'Datetime',
					@c_StorerKey as 'StorerKey',
					@PickSlipNo as 'PickSlip'
	END

             
	-----------------
	BEGIN TRANSACTION
	-----------------

	IF Exists(SELECT 1 FROM PackInfo WHERE PickSlipNo = @PickSlipNo and CartonNo = @CartonNo)
	BEGIN

			IF EXISTS (
					SELECT 1 
					FROM PICKHEADER PH (NOLOCK)
					JOIN Orders a (NOLOCK) on a.OrderKey = PH.OrderKey AND a.Status ='9'
					WHERE PH.PickHeaderKey = @PickSlipNo)
			BEGIN
			
				SET @c_Status = 'E'    
				SET @b_Success = 0    
				SET @n_Err = 50002    
				SET @c_Errmsg = 'Invalid Order Status(isp_CubicScan_WMSPIN_1)'
				GOTO Quit    

			END


			UPDATE Packinfo WITH (ROWLOCK)
			SET Weight = @Weight / 1000,
				Cube = (@Length*@Width*@Height)/(1000*1000*1000),
				Length = @Length / 10,
				Width = @Width / 10,
				Height = @Height / 10
			WHERE PickSlipNo = @PickSlipNo and CartonNo = @CartonNo

			IF @@Error <> 0 OR @@RowCount = 0
			BEGIN    
				SET @c_Status = '5'    
				SET @b_Success = 0    
				SET @n_Err = 50003    
				SET @c_Errmsg = 'Failed to update PackInfo(isp_CubicScan_WMSPIN_1)'
				GOTO Quit    
			END
	END
	ELSE
	BEGIN

			INSERT Packinfo (PickSlipNo, CartonNo, Weight, Cube, 
							Qty, CartonType, RefNo, Length, Width, Height)
			SELECT PickSlipNo, CartonNo, @Weight / 1000, (@Length*@Width*@Height)/(1000*1000*1000),
					SUM(Qty), '', '', @Length / 10, @Width / 10, @Height / 10
			FROM PackDetail 
			WHERE PickSlipNo = @PickSlipNo and LabelNo = @LabelNo
			group by PickSlipNo, CartonNo, LabelNo

			IF @@Error <> 0 OR @@RowCount = 0
			BEGIN    
				SET @c_Status = '5'    
				SET @b_Success = 0    
				SET @n_Err = 50004    
				SET @c_Errmsg = 'Failed to Insert PackInfo(isp_CubicScan_WMSPIN_1)'
				GOTO Quit    
			END

	END

	UPDATE TCPSocket_INLog WITH(RowLocK)          
	SET Status = '9', EditDate = GETDATE()            
	WHERE SerialNo = @n_SerialNo    

	IF @@Error <> 0
	BEGIN    
		SET @c_Status = '5'    
		SET @b_Success = 0    
		SET @n_Err = 50005    
		SET @c_Errmsg = 'Failed to update TCPSocket_INLog (isp_CubicScan_WMSPIN_1)'
		GOTO Quit    
	END

	------------------
	COMMIT TRANSACTION
	------------------
    RETURN  
	               
                
   -- Chee01  
   IF @c_Remarks <> '' AND ISNULL(@c_ErrMsg, '') = ''    
      SET @c_ErrMsg = @c_Remarks    
  
   QUIT:          


   IF @b_Success = 0
   BEGIN      		    

		IF @@TRANCOUNT > @n_StartTranCnt    
		ROLLBACK TRANSACTION    

		UPDATE TCPSocket_INLog WITH(ROWLOCK)          
		SET Status = @c_Status, EditDate = GETDATE(),
		   ErrMsg = @c_ErrMsg             
		WHERE SerialNo = @n_SerialNo
           
   END 

  
      
	

                
END    
      
/*

declare @c_MessageNum NVARCHAR(10), @c_SprocName NVARCHAR(30), @b_Success int, @n_Err int, @c_ErrMsg NVARCHAR(250)

exec isp_CubicScan_WMSPIN_1  2573751, 1
    ,@c_SprocName    
    ,@b_Success  OUTPUT  
    ,@n_Err  OUTPUT  
    ,@c_ErrMsg  OUTPUT  
 
select @c_MessageNum , @c_SprocName , @b_Success , @n_Err , @c_ErrMsg 



*/


GO